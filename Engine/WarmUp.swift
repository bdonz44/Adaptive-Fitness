import Foundation

public struct WarmUpStep: Equatable, Sendable {
    /// Percent of work weight; nil for the empty bar.
    public var percent: Int?
    /// Nil until a work weight is typed in set 1.
    public var weight: Double?
    public var reps: Int
    /// "Empty bar × 10", "40% × 5" before a weight is typed; "135 × 5" after.
    public var label: String
    /// "empty bar" or "45 per side".
    public var plates: String?
}

public enum WarmUp {
    public static let restSeconds = 60
    public static let placeholderHint = "Type your work weight in set 1 and these fill in."

    /// Warm-up ramp for the main lift, built from the weight typed in set 1.
    public static func ramp(lift: String, workWeight: Double?) -> [WarmUpStep] {
        let deadlift = lift == "deadlift"
        let floor: Double = deadlift ? 95 : 45
        var template: [(percent: Int?, reps: Int)] = deadlift
            ? [(40, 5), (60, 3), (80, 2)]
            : [(nil, 10), (40, 5), (60, 3), (80, 2)]

        guard let work = workWeight, work > 0 else {
            return template.map { step in
                let label = step.percent.map { "\($0)% × \(step.reps)" } ?? "Empty bar × \(step.reps)"
                return WarmUpStep(percent: step.percent, weight: nil, reps: step.reps, label: label, plates: nil)
            }
        }

        if work >= 225 { template.append((90, 1)) }
        var steps: [WarmUpStep] = []
        var seen = Set<Double>()
        for step in template {
            let raw = step.percent.map { work * Double($0) / 100 } ?? 45
            let w = max(floor, Suggestions.round5(raw))
            if w >= work || seen.contains(w) { continue }
            seen.insert(w)
            steps.append(WarmUpStep(percent: step.percent, weight: w, reps: step.reps,
                                    label: "\(Fmt.lb(w)) × \(step.reps)", plates: plates(w)))
        }
        return steps
    }

    /// "(W - 45) / 2 per side" or "empty bar".
    public static func plates(_ w: Double) -> String {
        if w <= 45 { return "empty bar" }
        return "\(Fmt.lb((w - 45) / 2)) per side"
    }
}
