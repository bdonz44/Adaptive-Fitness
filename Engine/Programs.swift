import Foundation

/// The programs you can run. Hybrid 12 is the original (web app) program;
/// the others are built from `ProgramLibrary` day plans.
public enum ProgramID: String, Codable, CaseIterable, Sendable {
    case hybrid12, engineStrength, define45, strengthBoxing, screenReady, agentCircuits, vo2Max, ripped,
         squatFocus, benchFocus, deadliftFocus, olympic

    public var name: String {
        switch self {
        case .hybrid12: return "Hybrid 12"
        case .engineStrength: return "Engine Strength"
        case .define45: return "Define 45"
        case .strengthBoxing: return "Strength & Boxing"
        case .screenReady: return "Screen Ready"
        case .agentCircuits: return "Agent Circuits"
        case .vo2Max: return "VO2 Max"
        case .ripped: return "Ripped"
        case .squatFocus: return "Squat Builder"
        case .benchFocus: return "Bench Builder"
        case .deadliftFocus: return "Deadlift Builder"
        case .olympic: return "Olympic Lifts"
        }
    }

    public var blurb: String {
        switch self {
        case .hybrid12:
            return "Strength plus conditioning. Lose fat, keep muscle."
        case .engineStrength:
            return "Heavy lifting plus Norwegian 4×4, kettlebell snatch and circuit intervals to raise your VO2 max."
        case .define45:
            return "Upper / lower strength and muscle work, 12-16 hard sets per muscle a week, short conditioning. Defined and stronger."
        case .strengthBoxing:
            return "Power cleans, presses and pulls for punching power, plus heavy bag technique, power and fight-pace rounds."
        case .screenReady:
            return "The actor cut: chest, shoulders, arms and abs twice a week on top of heavy lifts, with rest shrinking toward camera-ready."
        case .agentCircuits:
            return "About 45 minutes: one heavy lift, then kettlebell, TRX, dumbbell-complex or bag circuits. Lean, athletic, easy on the joints."
        case .vo2Max:
            return "Cardio first: two hard interval days a week (Norwegian 4×4 and 30/30s), the rest easy Zone 2, plus short heavy lifting to keep your strength. Built to raise VO2 max."
        case .ripped:
            return "Get lean and show the muscle: heavy lifts kept heavy, every muscle twice a week in fast supersets, abs every day and finishers that burn fat."
        case .squatFocus:
            return "Raise your squat: squat 3-4 times a week (heavy, volume, pause and front squats), building from 5s to heavy doubles over 12 weeks."
        case .benchFocus:
            return "Raise your bench: bench 3-4 times a week (heavy, volume, pause and close-grip), with the back, shoulders and triceps that move it."
        case .deadliftFocus:
            return "Raise your deadlift: a heavy pull and a deficit pull every week, plus the squats, hinges and back work that build it."
        case .olympic:
            return "Learn and build the cleans and snatches: technique from the hang first, then full power lifts, on a front squat and pulling base."
        }
    }

    /// Days-a-week choices.
    public var dayOptions: [Int] { self == .hybrid12 ? [5] : [3, 4, 5] }
    public var defaultDays: Int { self == .hybrid12 ? 5 : 4 }

    public func phaseName(_ phase: Phase) -> String {
        switch self {
        case .hybrid12: return phase.name
        case .engineStrength: return ["Base", "Build", "Peak"][phase.rawValue]
        case .define45: return ["Build", "Sculpt", "Define"][phase.rawValue]
        case .strengthBoxing: return ["Fundamentals", "Power", "Fight Shape"][phase.rawValue]
        case .screenReady: return ["Build", "Cut", "Camera Ready"][phase.rawValue]
        case .agentCircuits: return ["Base", "Operator", "Mission"][phase.rawValue]
        case .vo2Max: return ["Base", "Build", "Peak"][phase.rawValue]
        case .ripped: return ["Lean Out", "Carve", "Ripped"][phase.rawValue]
        case .squatFocus, .benchFocus, .deadliftFocus: return ["Volume", "Strength", "Peak"][phase.rawValue]
        case .olympic: return ["Technique", "Power", "Peak"][phase.rawValue]
        }
    }

    public func phaseBlurb(_ phase: Phase) -> String {
        switch (self, phase) {
        case (.hybrid12, _): return ""
        case (.engineStrength, .foundation): return "Heavy 5s, 4×4 intervals, 10 min of snatches."
        case (.engineStrength, .build): return "Heavier 3-5s, longer snatch blocks and circuits."
        case (.engineStrength, .define): return "Heavy triples, 5 hard 4×4 rounds, 20 min snatch blocks."
        case (.define45, .foundation): return "6-8 rep strength, 10-15 rep muscle work."
        case (.define45, .build): return "Heavier 5-6s, more sets, three pairs on upper days."
        case (.define45, .define): return "Heavy 4-6s, faster pace, more conditioning."
        case (.strengthBoxing, .foundation): return "Learn the combos; heavy 5s."
        case (.strengthBoxing, .build): return "Cleans and heavy 3-5s; hard power rounds."
        case (.strengthBoxing, .define): return "Fight-pace rounds; strength held at 3s."
        case (.screenReady, .foundation): return "Heavy 6-8s, 10-15 rep pump work. Eat near maintenance."
        case (.screenReady, .build): return "Same lifts, shorter rest, 300-500 calorie deficit."
        case (.screenReady, .define): return "4 × 12-15 on 30 sec rest, more abs and incline walking. Main lifts stay heavy."
        case (.agentCircuits, .foundation): return "Heavy 5s, 3-lap circuits."
        case (.agentCircuits, .build): return "4-6s, 4-lap circuits."
        case (.agentCircuits, .define): return "Heavy 3-5s, 5-lap circuits, faster switches."
        case (.vo2Max, .foundation): return "4 rounds of 4×4, 16 × 30/30, 35-45 min Zone 2. Lifts 3 × 5."
        case (.vo2Max, .build): return "5 rounds of 4×4, 20 × 30/30, longer Zone 2. Lifts held, fewer sets."
        case (.vo2Max, .define): return "5 hard 4×4 rounds, 24 × 30/30, up to 70 min Zone 2. Retest VO2 max at week 12."
        case (.ripped, .foundation): return "Heavy 6-8s, 10-12 rep supersets on 60 sec rest. Deficit starts."
        case (.ripped, .build): return "Heavy 5-6s, 12-15 reps on 45 sec rest. Longer finishers."
        case (.ripped, .define): return "Main lifts stay heavy; 4 × 12-15 on 30 sec rest, max finishers."
        case (.squatFocus, .foundation), (.benchFocus, .foundation), (.deadliftFocus, .foundation):
            return "Heavy 5s, volume 8s, technique triples. Build the base."
        case (.squatFocus, .build), (.benchFocus, .build), (.deadliftFocus, .build):
            return "Heavy triples, volume 6s. Heavier every week."
        case (.squatFocus, .define), (.benchFocus, .define), (.deadliftFocus, .define):
            return "Heavy doubles and singles, less volume. Test a new max in week 12."
        case (.olympic, .foundation): return "Hang snatches and cleans, triples. Positions and speed before weight."
        case (.olympic, .build): return "Doubles; full power cleans and snatches come in. Front squat triples."
        case (.olympic, .define): return "Heavy singles and doubles on the full lifts. Test them in week 12."
        }
    }

    public var howItWorks: String {
        switch self {
        case .hybrid12:
            return "Do the five sessions in order, on any days. Finishing all five starts the next week. Weeks 4 and 8 are back-off weeks. After week 12, cycle 2 starts with your weights carried over."
        case .engineStrength:
            return "Lift first, then the engine work, so the lifts stay heavy and fast. Intervals are hard: about 85-95% of max heart rate (150-168 bpm at 45) on the work, easy on the rest. Add speed or incline when the last round feels steady. Weeks 4 and 8 back off. Test your VO2 max (Apple Watch Cardio Fitness or a 12-minute run) at weeks 1, 6 and 12."
        case .define45:
            return "Each muscle gets about 12-16 hard sets a week. Stop heavy sets 1-3 reps short of failure. Eat 300-500 calories under maintenance, protein 1 g per lb of goal weight, 8-10k steps a day, 7+ hours of sleep. Weeks 4 and 8 back off."
        case .strengthBoxing:
            return "Strength before the bag on lifting days. Rounds are 3 min with 1 min rest. Hands back to your face after every punch, breathe out on every punch, and stay on the balls of your feet. Wrap your hands. Weeks 4 and 8 back off."
        case .screenReady:
            return "What actor trainers do: a heavy compound lift first so you keep strength while cutting, then supersets for chest, shoulders, arms and abs, each hit twice a week. Lower every rep over 2-3 seconds. 10k steps a day, protein 1 g per lb of goal weight, lose 0.5-1% a week. No water cutting: the Camera Ready phase gets you there by being lean, not dehydrated. Weeks 4 and 8 back off."
        case .agentCircuits:
            return "About 45 minutes. One heavy lift with full rest, a quick pair, then the circuit at a pace you can hold every lap. Circuits get longer each phase. Weeks 4 and 8 back off."
        case .vo2Max:
            return "Mostly easy, some very hard: most of your cardio time (70-80%) is easy Zone 2 (you can talk in full sentences, about 105-125 bpm), 20% is hard intervals at 90%+ of max heart rate (158+ bpm at a max of 176). Hard days are never back to back; the app puts an easy day between them. Warm up 10 min before intervals. Lifting is short and heavy to keep strength, never before the intervals. Treadmill, bike, rower or the heavy bag all count: heart rate is what matters. Test your VO2 max at weeks 1, 6 and 12 (Apple Watch Cardio Fitness, or the farthest you can run in 12 minutes). Weeks 4 and 8 back off."
        case .ripped:
            return "Muscle is kept by lifting heavy while you diet, so the first lift stays heavy all 12 weeks. Every muscle is trained twice a week, about 12-20 hard sets, in supersets that keep each session to about 50-60 minutes. Rest shrinks each phase. Stop sets 1-2 reps short of failure; lower every rep over 2-3 seconds. Eat 300-500 calories under maintenance, protein 1 g per lb of goal weight, 10k steps a day, 7+ hours of sleep; lose 0.5-1% of bodyweight a week. Abs show when you're lean enough: the daily ab work makes them thicker, the deficit reveals them. Weeks 4 and 8 back off."
        case .squatFocus:
            return "Squatting 3-4 times a week builds more practice and strength than once, and the weeks move from volume (5s and 8s) to strength (triples) to peak (doubles and singles). Heavy day: leave 1-2 reps in the tank. Pause squats fix the hole, front squats fix the upright torso. Use the rack's safety arms on every heavy set: you train alone. Weeks 4 and 8 back off; in week 12, work up to a heavy single you could do again (no grinders) for your new max."
        case .benchFocus:
            return "Benching 3-4 times a week with different rep ranges: heavy, volume, pause (no bounce: strength off the chest) and close-grip (lockout). Rows and face pulls every week keep the shoulders healthy. Shoulder blades pinned, feet down, bar to the lower chest. Use safety arms or pins: you bench alone. Weeks 4 and 8 back off; test a heavy single in week 12."
        case .deadliftFocus:
            return "A heavy pull and a deficit pull each week (more is hard to recover from), plus squats, RDLs and hip thrusts for the legs and hips, and rows for the back. Reset every rep: no touch-and-go on heavy sets. Stop a set when the back rounds. Weeks 4 and 8 back off; test a heavy single in week 12."
        case .olympic:
            return "Olympic lifts reward speed and position over weight. Learn from the hang (above the knee) before lifting from the floor, and stop a set when the bar slows or drifts forward. Bumper plates and a platform if you have them; learn to dump a snatch forward or back. Front squats and pulls build the strength to catch heavier. Filming a set from the side is the best coach you have at home. Weeks 4 and 8 back off."
        }
    }
}

extension ProgramState {
    /// The week within the running program (week 1 = its first week).
    public var programWeek: ProgramWeek { ProgramWeek(week - startWeek + 1) }

    /// The required sessions this week, in order.
    public var order: [Slot] { ProgramLibrary.order(program, days: days) }

    /// Leg-heavy sessions (not two days in a row).
    public var lower: [Slot] { ProgramLibrary.lower(program, days: days) }

    /// Name of a session in the running program.
    public func slotName(_ slot: Slot) -> String { ProgramLibrary.name(slot, program: program, days: days) }

    // MARK: Saving in the synced program record

    /// The program, days, start week and other programs' saved weeks ride along in the
    /// synced record's done list as "@..." entries, so the iCloud schema doesn't change.
    static let markerPrefix = "@"

    public var storedDoneSlots: [String] {
        var out = doneSlots
        if program != .hybrid12 || startWeek != 1 || days != program.defaultDays {
            out.append("@p:\(program.rawValue):\(days):\(startWeek)")
        }
        for (id, wk) in resumeWeeks.sorted(by: { $0.key < $1.key }) { out.append("@r:\(id):\(wk)") }
        return out
    }

    /// Reads a stored done list back (older records have no "@" entries: Hybrid 12).
    public mutating func applyStored(doneSlots stored: [String]) {
        doneSlots = stored.filter { !$0.hasPrefix(Self.markerPrefix) }
        program = .hybrid12
        days = ProgramID.hybrid12.defaultDays
        startWeek = 1
        resumeWeeks = [:]
        for entry in stored where entry.hasPrefix(Self.markerPrefix) {
            let parts = entry.dropFirst().split(separator: ":").map(String.init)
            if parts.first == "p", parts.count == 4, let id = ProgramID(rawValue: parts[1]),
               let d = Int(parts[2]), let s = Int(parts[3]) {
                program = id
                days = id.dayOptions.contains(d) ? d : id.defaultDays
                startWeek = min(s, week)
            } else if parts.first == "r", parts.count == 3, let w = Int(parts[2]) {
                resumeWeeks[parts[1]] = w
            }
        }
    }
}

extension Program {
    /// Switch programs. The current program's week is kept so you can come back to it;
    /// the new one starts where you left it (or week 1) on a fresh week number, so
    /// logs from different programs never share a week.
    public static func switchTo(_ id: ProgramID, days: Int, state: ProgramState) -> ProgramState {
        var s = state
        let d = id.dayOptions.contains(days) ? days : id.defaultDays
        if id == s.program {
            s.days = d
            s.doneSlots = s.doneSlots.filter { slot in s.order.contains { $0.rawValue == slot } }
            return s
        }
        s.resumeWeeks[s.program.rawValue] = s.programWeek.week
        let resume = s.resumeWeeks.removeValue(forKey: id.rawValue) ?? 1
        s.week += 1
        s.startWeek = s.week - (resume - 1)
        s.program = id
        s.days = d
        s.doneSlots = []
        return s
    }
}
