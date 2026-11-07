import AuthenticationServices
import Foundation
import Observation
import Security
import Hybrid12Engine

/// Signs in to WHOOP (OAuth) and fetches today's recovery, sleep and strain.
/// Tokens live in the Keychain; today's numbers are cached in UserDefaults.
@Observable
final class WhoopService {
    static let redirect = "hybrid12://whoop"
    private static let base = "https://api.prod.whoop.com"
    private static let scopes = "offline read:recovery read:cycles read:sleep read:workout read:profile"
    private static let todayKey = "whoop.today"

    private(set) var today: WhoopToday?
    private(set) var isConnected = false
    private(set) var isSyncing = false
    private(set) var lastError: String?

    private let clientID = Bundle.main.object(forInfoDictionaryKey: "WhoopClientID") as? String ?? ""
    private let clientSecret = Bundle.main.object(forInfoDictionaryKey: "WhoopClientSecret") as? String ?? ""

    /// False when the app was built without the WHOOP keys.
    var isConfigured: Bool { !clientID.isEmpty && !clientSecret.isEmpty && !clientID.hasPrefix("$(") }

    init() {
        isConnected = Keychain.get("whoop.refresh") != nil
        if let data = UserDefaults.standard.data(forKey: Self.todayKey) {
            today = try? JSONDecoder().decode(WhoopToday.self, from: data)
        }
    }

    // MARK: Sign in

    /// The WHOOP sign-in page. `state` must be echoed back.
    func authorizeURL(state: String) -> URL? {
        var c = URLComponents(string: Self.base + "/oauth/oauth2/auth")
        c?.queryItems = [
            .init(name: "response_type", value: "code"),
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: Self.redirect),
            .init(name: "scope", value: Self.scopes),
            .init(name: "state", value: state),
        ]
        return c?.url
    }

    /// Finishes sign-in with the URL WHOOP sent back.
    @MainActor
    func complete(callback: URL, state: String) async {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard items.first(where: { $0.name == "state" })?.value == state,
              let code = items.first(where: { $0.name == "code" })?.value else {
            lastError = items.first(where: { $0.name == "error_description" })?.value ?? "WHOOP sign-in was cancelled."
            return
        }
        do {
            try await token(["grant_type": "authorization_code", "code": code, "redirect_uri": Self.redirect])
            isConnected = true
            lastError = nil
            await sync(force: true)
        } catch {
            lastError = "Couldn't finish WHOOP sign-in. \(error.localizedDescription)"
        }
    }

    func disconnect() {
        Keychain.delete("whoop.access")
        Keychain.delete("whoop.refresh")
        UserDefaults.standard.removeObject(forKey: Self.todayKey)
        today = nil
        isConnected = false
    }

    // MARK: Data

    /// Fetches today's numbers unless they were fetched in the last 20 minutes.
    @MainActor
    func sync(force: Bool = false) async {
        guard isConnected, !isSyncing else { return }
        if !force, let t = today, Date().timeIntervalSince(t.fetchedAt) < 20 * 60 { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let recovery = try await get("/developer/v2/recovery?limit=1")
            let sleep = try await get("/developer/v2/activity/sleep?limit=5")
            let cycle = try await get("/developer/v2/cycle?limit=1")
            let t = Self.parse(recovery: recovery, sleep: sleep, cycle: cycle)
            today = t
            if let data = try? JSONEncoder().encode(t) { UserDefaults.standard.set(data, forKey: Self.todayKey) }
            lastError = nil
        } catch WhoopError.signedOut {
            disconnect()
            lastError = "WHOOP signed you out. Connect again."
        } catch {
            lastError = "Couldn't reach WHOOP. \(error.localizedDescription)"
        }
    }

    static func parse(recovery: [String: Any], sleep: [String: Any], cycle: [String: Any]) -> WhoopToday {
        var t = WhoopToday(fetchedAt: Date())
        if let r = (recovery["records"] as? [[String: Any]])?.first, r["score_state"] as? String == "SCORED",
           let s = r["score"] as? [String: Any] {
            t.recovery = (s["recovery_score"] as? NSNumber)?.intValue
            t.hrv = (s["hrv_rmssd_milli"] as? NSNumber)?.doubleValue
            t.restingHR = (s["resting_heart_rate"] as? NSNumber)?.intValue
        }
        let sleeps = (sleep["records"] as? [[String: Any]]) ?? []
        if let main = sleeps.first(where: { ($0["nap"] as? Bool) != true }), main["score_state"] as? String == "SCORED",
           let s = main["score"] as? [String: Any], let stages = s["stage_summary"] as? [String: Any] {
            let asleep = ["total_light_sleep_time_milli", "total_slow_wave_sleep_time_milli", "total_rem_sleep_time_milli"]
                .compactMap { (stages[$0] as? NSNumber)?.doubleValue }.reduce(0, +)
            t.sleepHours = asleep / 3_600_000
            t.sleepPerformance = (s["sleep_performance_percentage"] as? NSNumber)?.intValue
        }
        if let c = (cycle["records"] as? [[String: Any]])?.first {
            t.strain = ((c["score"] as? [String: Any])?["strain"] as? NSNumber)?.doubleValue
            if let start = c["start"] as? String { t.cycleStart = ISO8601DateFormatter.whoop.date(from: start) }
        }
        return t
    }

    /// WHOOP's scored workouts between two times (for the Finish screen).
    @MainActor
    func workouts(from start: Date, to end: Date) async -> [WhoopWorkout]? {
        guard isConnected else { return nil }
        var c = URLComponents()
        c.queryItems = [.init(name: "start", value: WhoopDate.string(start)),
                        .init(name: "end", value: WhoopDate.string(end)),
                        .init(name: "limit", value: "10")]
        let query = c.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B") ?? ""
        do {
            return WhoopWorkout.parse(try await get("/developer/v2/activity/workout?" + query))
        } catch WhoopError.signedOut {
            disconnect()
            lastError = "WHOOP signed you out. Connect again."
            return nil
        } catch {
            return nil
        }
    }

    // MARK: HTTP

    enum WhoopError: Error { case signedOut, http(Int) }

    private func get(_ path: String, retry: Bool = true) async throws -> [String: Any] {
        guard let access = Keychain.get("whoop.access") else {
            try await refresh()
            return try await get(path, retry: false)
        }
        var req = URLRequest(url: URL(string: Self.base + path)!)
        req.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401, retry {
            try await refresh()
            return try await get(path, retry: false)
        }
        guard code == 200 else { throw code == 401 ? WhoopError.signedOut : WhoopError.http(code) }
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func refresh() async throws {
        guard let refresh = Keychain.get("whoop.refresh") else { throw WhoopError.signedOut }
        try await token(["grant_type": "refresh_token", "refresh_token": refresh, "scope": "offline"])
    }

    private func token(_ fields: [String: String]) async throws {
        var req = URLRequest(url: URL(string: Self.base + "/oauth/oauth2/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var all = fields
        all["client_id"] = clientID
        all["client_secret"] = clientSecret
        req.httpBody = all.map { "\($0.key)=\(Self.formEncode($0.value))" }.joined(separator: "&").data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["access_token"] as? String else {
            throw code == 400 || code == 401 ? WhoopError.signedOut : WhoopError.http(code)
        }
        Keychain.set(access, for: "whoop.access")
        if let r = json["refresh_token"] as? String { Keychain.set(r, for: "whoop.refresh") }
    }

    private static func formEncode(_ s: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }
}

extension ISO8601DateFormatter {
    static let whoop: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

/// Minimal Keychain storage for the WHOOP tokens (this device only).
enum Keychain {
    static func set(_ value: String, for key: String) {
        delete(key)
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key,
                                kSecValueData as String: Data(value.utf8),
                                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        SecItemAdd(q as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key,
                                kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key]
        SecItemDelete(q as CFDictionary)
    }
}
