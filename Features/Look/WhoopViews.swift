import AuthenticationServices
import SwiftUI
import Hybrid12Engine

/// Today's WHOOP recovery at the top of Today (when connected).
struct WhoopCard: View {
    @Environment(WhoopService.self) private var whoop

    var body: some View {
        if whoop.isConnected, let t = whoop.today, let r = t.recovery {
            let look = Theme.look
            let color = zoneColor(WhoopReadiness.zone(r))
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    SectionLabel(text: "WHOOP recovery", color: color)
                    Spacer()
                    if let strain = t.strain {
                        Text("Strain \(String(format: "%.1f", strain))").font(.caption).foregroundStyle(look.secondary)
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(r)%").font(look.number(look.readinessFirst ? 56 : 40)).foregroundStyle(color)
                    Text(WhoopReadiness.summary(t).replacingOccurrences(of: "Recovery \(r)% · ", with: ""))
                        .font(.subheadline).foregroundStyle(look.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let line = WhoopReadiness.coachLine(t) {
                    Text(line).font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                }
                if !WhoopReadiness.isCurrent(t, now: Date()) {
                    Text("From \(t.fetchedAt.formatted(.relative(presentation: .named))). Open WHOOP to sync, then come back.")
                        .font(.caption).foregroundStyle(look.secondary)
                }
            }
            .padding(16)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: look.radius))
            .overlay(RoundedRectangle(cornerRadius: look.radius).stroke(color.opacity(0.5)))
        } else if whoop.isConnected, whoop.today != nil {
            Text("WHOOP hasn't scored today's recovery yet.")
                .font(.caption).foregroundStyle(Theme.secondary)
        }
    }
}

func zoneColor(_ z: WhoopReadiness.Zone) -> Color {
    switch z {
    case .green: return Color(hex: 0x22C55E)
    case .yellow: return Color(hex: 0xEAB308)
    case .red: return Color(hex: 0xEF4444)
    }
}

/// Connect or disconnect WHOOP.
struct WhoopSettingsView: View {
    @Environment(WhoopService.self) private var whoop
    @Environment(AppStore.self) private var store
    @Environment(\.webAuthenticationSession) private var webAuth
    @State private var working = false

    var body: some View {
        let look = Theme.look
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Hybrid 12 reads your WHOOP recovery, sleep and strain each time you open the app. Recovery sets \"How do you feel?\" (green Great, yellow Normal, red Beat up) and how hard the coach pushes. You can still change it by hand.")
                    .font(.subheadline).foregroundStyle(look.secondary)
                if !whoop.isConfigured {
                    Text("This build doesn't have the WHOOP keys. Ask Claude to rebuild it.")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.red)
                } else if whoop.isConnected {
                    WhoopCard()
                    if let t = whoop.today {
                        Text("Last synced \(t.fetchedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.caption).foregroundStyle(look.secondary)
                    }
                    Button {
                        Task { await whoop.sync(force: true); store.applyWhoop(whoop.today) }
                    } label: { Text(whoop.isSyncing ? "Syncing…" : "Sync now").accentButton() }
                        .buttonStyle(.plain)
                        .disabled(whoop.isSyncing)
                    Button("Disconnect WHOOP", role: .destructive) { whoop.disconnect() }
                        .frame(maxWidth: .infinity)
                } else {
                    Button { Task { await connect() } } label: {
                        Text(working ? "Opening WHOOP…" : "Connect WHOOP").accentButton(height: 60)
                    }
                    .buttonStyle(.plain)
                    .disabled(working)
                    Text("You'll sign in to WHOOP once. Hybrid 12 only reads your data.")
                        .font(.caption).foregroundStyle(look.secondary)
                }
                if let error = whoop.lastError {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
            }
            .padding()
        }
        .background(look.background)
        .navigationTitle("WHOOP")
    }

    private func connect() async {
        working = true
        defer { working = false }
        let state = UUID().uuidString
        guard let url = whoop.authorizeURL(state: state) else { return }
        do {
            let callback = try await webAuth.authenticate(using: url, callbackURLScheme: "hybrid12",
                                                         preferredBrowserSession: .shared)
            await whoop.complete(callback: callback, state: state)
            store.applyWhoop(whoop.today)
        } catch {
            // Cancelled by the user: nothing to do.
        }
    }
}
