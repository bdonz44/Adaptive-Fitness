import Foundation

/// Matching what you tell the AI coach ("bench", "the curls", "TRX chest fly") to today's
/// session and the exercise library.
public enum CoachActions {
    static func words(_ s: String) -> Set<String> {
        Set(s.lowercased().replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 1 && !["the", "my", "db", "kb", "bb", "a", "an", "of", "and"].contains($0) }
            .map { $0.hasSuffix("s") && $0.count > 2 && !$0.hasSuffix("ss") ? String($0.dropLast()) : $0 })
    }

    /// Every word you said has to be in the name; fewer extra words in the name wins.
    static func score(_ query: String, _ name: String) -> Int {
        let q = query.lowercased(), n = name.lowercased()
        if q == n { return 1000 }
        let qw = words(q), nw = words(n)
        guard !qw.isEmpty else { return 0 }
        if qw.isSubset(of: nw) { return 100 - (nw.count - qw.count) }
        if n.contains(q) { return 50 }
        return 0
    }

    /// The item in today's session that best matches a name (lifts and conditioning).
    public static func item(_ name: String, in session: Session) -> SessionItem? {
        let scored = session.items.map { ($0, score(name, $0.name)) }.filter { $0.1 > 0 }
        return scored.max { $0.1 < $1.1 }?.0
    }

    /// The library exercise that best matches a name, among those you have the gear for.
    public static func exercise(_ name: String, catalog: Catalog = .bundled, gear: GearProfile = .standard,
                                excluding: Set<String> = []) -> Exercise? {
        let all = (catalog.mainLifts + catalog.accessories).filter { gear.has($0) && !excluding.contains($0.id) }
        let scored = all.map { ($0, score(name, $0.name)) }.filter { $0.1 > 0 }
        return scored.max { $0.1 < $1.1 }?.0
    }
}
