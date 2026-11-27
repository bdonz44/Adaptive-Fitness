import Foundation

// MARK: - 10. Goal planner and 6. next-block autopilot

public struct Goal: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case vo2Max, bodyweight, lift
        public var name: String {
            switch self {
            case .vo2Max: return "VO2 max"
            case .bodyweight: return "Bodyweight"
            case .lift: return "Lift a weight"
            }
        }
    }

    public var kind: Kind
    public var target: Double
    /// For `.lift`: the exercise (squat, bench, deadlift, ohp).
    public var liftID: String?
    public var start: Date
    public var deadline: Date
    /// Where you were when the goal was set.
    public var startValue: Double?

    public init(kind: Kind, target: Double, liftID: String? = nil, start: Date, deadline: Date, startValue: Double?) {
        self.kind = kind; self.target = target; self.liftID = liftID
        self.start = start; self.deadline = deadline; self.startValue = startValue
    }

    /// "VO2 max 45 by Jun 1", "185 lb by Jul 4", "Squat 315 by Mar 1"
    public func title(liftName: String? = nil) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        let by = " by " + f.string(from: deadline)
        switch kind {
        case .vo2Max: return "VO2 max \(Fmt.lb(target))" + by
        case .bodyweight: return "\(Fmt.lb(target)) lb" + by
        case .lift: return "\(liftName ?? "Lift") \(Fmt.lb(target))" + by
        }
    }
}

public enum GoalPlanner {
    /// Programs that serve each goal, in the order they're run.
    public static func rotation(_ kind: Goal.Kind) -> [ProgramID] {
        switch kind {
        case .vo2Max: return [.vo2Max, .engineStrength]
        case .bodyweight: return [.ripped, .define45]
        case .lift: return [.hybrid12, .engineStrength]
        }
    }

    public struct Block: Equatable, Sendable {
        public var program: ProgramID
        public var starts: Date
    }

    /// 12-week blocks from now to the deadline: the current program finishes its block if it
    /// serves the goal, then the goal's programs take turns.
    public static func plan(_ goal: Goal, current: ProgramID, weeksLeftInBlock: Int, now: Date) -> [Block] {
        let rot = rotation(goal.kind)
        var blocks: [Block] = []
        var date = now
        var next: ProgramID
        if rot.contains(current) {
            blocks.append(Block(program: current, starts: now))
            date = now.addingTimeInterval(Double(max(1, weeksLeftInBlock)) * 7 * 86400)
            next = rot[(rot.firstIndex(of: current)! + 1) % rot.count]
        } else {
            next = rot[0]
        }
        while date < goal.deadline && blocks.count < 8 {
            blocks.append(Block(program: next, starts: date))
            date = date.addingTimeInterval(12 * 7 * 86400)
            next = rot[(rot.firstIndex(of: next)! + 1) % rot.count]
        }
        return blocks
    }

    public struct Status: Equatable, Sendable {
        public var expected: Double
        public var actual: Double
        public var onTrack: Bool
        public var done: Bool
        public var text: String
    }

    /// On track when the latest value is at least as far along as a straight line from start to goal.
    public static func status(_ goal: Goal, current: Double?, now: Date) -> Status? {
        guard let current, let start = goal.startValue, goal.deadline > goal.start else { return nil }
        let total = goal.deadline.timeIntervalSince(goal.start)
        let t = min(1, max(0, now.timeIntervalSince(goal.start) / total))
        let expected = start + (goal.target - start) * t
        let up = goal.target >= start
        let done = up ? current >= goal.target : current <= goal.target
        let onTrack = done || (up ? current >= expected - 0.01 : current <= expected + 0.01)
        let weeksLeft = max(0, Int((goal.deadline.timeIntervalSince(now) / (7 * 86400)).rounded()))
        let unit = goal.kind == .vo2Max ? "" : " lb"
        let text: String
        if done {
            text = "Goal reached: \(Fmt.lb(current))\(unit). Set the next one."
        } else if onTrack {
            text = "On track: \(Fmt.lb(current))\(unit) now, \(Fmt.lb(goal.target))\(unit) in \(weeksLeft) weeks."
        } else {
            text = "Behind: \(Fmt.lb(current))\(unit) now, the line says \(Fmt.lb((expected * 10).rounded() / 10))\(unit). \(weeksLeft) weeks left."
        }
        return Status(expected: expected, actual: current, onTrack: onTrack, done: done, text: text)
    }

    /// How the block that's ending went.
    public struct BlockResults: Equatable, Sendable {
        /// Share of planned sessions done (0-1).
        public var adherence: Double
        /// Bodyweight change over the block, % (negative = lost).
        public var weightChangePct: Double?
        /// Average change in main-lift estimated max, %.
        public var strengthChangePct: Double?
        /// VO2 max change (ml/kg/min) or heart-rate recovery change (bpm), whichever is known.
        public var fitnessChange: Double?
        public init(adherence: Double, weightChangePct: Double? = nil, strengthChangePct: Double? = nil, fitnessChange: Double? = nil) {
            self.adherence = adherence; self.weightChangePct = weightChangePct
            self.strengthChangePct = strengthChangePct; self.fitnessChange = fitnessChange
        }
    }

    /// The next 12 weeks: the goal's next program when a goal is set, else what the results call for.
    public static func nextBlock(after current: ProgramID, goal: Goal?, results: BlockResults,
                                 aboveGoalWeight: Bool = true) -> (program: ProgramID, reason: String) {
        if let goal {
            let rot = rotation(goal.kind)
            let next = rot.contains(current) ? rot[(rot.firstIndex(of: current)! + 1) % rot.count] : rot[0]
            return (next, "Next step toward \(goal.kind.name.lowercased()): \(next.name).")
        }
        if results.adherence < 0.6 {
            return (current, "You did \(Int((results.adherence * 100).rounded()))% of the sessions. Run \(current.name) again, 3 days a week if that's easier, and own it.")
        }
        if aboveGoalWeight, let w = results.weightChangePct, w > -1, current != .ripped {
            return (.ripped, "Your weight barely moved this block. Ripped keeps the muscle and gets the fat moving.")
        }
        if let f = results.fitnessChange, f <= 0, current != .vo2Max {
            return (.vo2Max, "Your fitness numbers stalled. VO2 Max puts cardio first for 12 weeks.")
        }
        if let s = results.strengthChangePct, s < 0 {
            return (.hybrid12, "Your lifts slipped. Hybrid 12 rebuilds strength with conditioning on top.")
        }
        let follow: [ProgramID: ProgramID] = [
            .vo2Max: .engineStrength, .engineStrength: .vo2Max, .ripped: .define45, .define45: .ripped,
            .hybrid12: .engineStrength, .screenReady: .define45, .strengthBoxing: .engineStrength, .agentCircuits: .hybrid12,
        ]
        let next = follow[current] ?? .hybrid12
        return (next, "Good block. Change the stimulus: \(next.name) keeps you improving.")
    }
}
