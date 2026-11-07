import Foundation

/// Day plans for the programs beyond Hybrid 12 (Engine Strength, Define 45, Strength & Boxing),
/// each with 3, 4 and 5 day weeks. Research notes are in README ("Programs").
public enum ProgramLibrary {

    // MARK: Building blocks

    /// How a lift is dosed. Each role has a (sets, low, high, rest) per phase.
    public enum Role: Sendable { case power, main, strength, accessory }

    public struct Dose: Sendable {
        let sets: Int, low: Int, high: Int, rest: Int
        init(_ sets: Int, _ low: Int, _ high: Int, _ rest: Int) {
            self.sets = sets; self.low = low; self.high = high; self.rest = rest
        }
    }

    /// One lift in a day. `ids` holds one exercise, or one per phase.
    public struct Lift: Sendable {
        let key: String
        let role: Role
        let ids: [String]
        func id(_ phase: Phase) -> String { ids.count == 3 ? ids[phase.rawValue] : ids[0] }
    }

    /// An interval, circuit, bag or easy cardio block.
    public struct Cardio: Sendable {
        let name: String
        /// Rounds per phase (minutes for easy cardio).
        let rounds: [Int]
        let work: Int?
        let rest: Int?
        let minPerRound: Double
        let unit: ExerciseUnit
        /// One description, or one per phase.
        let details: [String]
        /// Heart-rate target during the work, % of max.
        var target: ClosedRange<Int>? = nil
        func detail(_ phase: Phase) -> String { details.count == 3 ? details[phase.rawValue] : details[0] }
    }

    public struct Day: Sendable {
        public let name: String
        public let lower: Bool
        /// Power, main, strength lifts in order ("Get strong").
        let lifts: [Lift]
        /// Superset pairs: [[a, b], [c, d]] (ids, one per phase or one for all).
        let pairs: [[[String]]]
        /// Main conditioning (kept when time is short; only trimmed to half).
        let engine: Cardio?
        let engineBlock: BlockKind
        /// Add-on conditioning at the end (first thing cut when time is short).
        let finisher: Cardio?

        init(_ name: String, lower: Bool = false, lifts: [Lift], pairs: [[[String]]] = [],
             engine: Cardio? = nil, engineBlock: BlockKind = .engine, finisher: Cardio? = nil) {
            self.name = name; self.lower = lower; self.lifts = lifts; self.pairs = pairs
            self.engine = engine; self.engineBlock = engineBlock; self.finisher = finisher
        }
    }

    struct Spec: Sendable {
        let doses: [Role: [Dose]]
        let days: [Int: [Day]]
    }

    static func p(_ key: String, _ ids: String...) -> Lift { Lift(key: key, role: .power, ids: ids) }
    static func m(_ ids: String...) -> Lift { Lift(key: "main", role: .main, ids: ids) }
    static func s(_ key: String, _ ids: String...) -> Lift { Lift(key: key, role: .strength, ids: ids) }
    static func pair(_ a: String, _ b: String) -> [[String]] { [[a], [b]] }

    static let holds: [(Int, Int)] = [(30, 45), (40, 60), (45, 60)]

    // MARK: Conditioning

    static let norwegian = Cardio(
        name: "Norwegian 4×4", rounds: [4, 4, 5], work: 240, rest: 180, minPerRound: 7, unit: .rounds,
        details: ["Treadmill at 6-10% incline (or a hill). 4 min hard: 85-95% of max heart rate (about 150-168 bpm), breathing hard, only a few words. 3 min easy walk. Same speed every round; add speed or incline when round 4 feels steady."], target: 85...95)
    static let snatch = Cardio(
        name: "KB Snatch 15:15", rounds: [20, 30, 40], work: 15, rest: 15, minPerRound: 0.5, unit: .rounds,
        details: ["15 sec of kettlebell snatches, 15 sec rest, switch hands every round. 20 or 35 lb bell. Smooth hips, punch through at the top. If form slips, swap to swings for the round."], target: 80...90)
    static let circuit = Cardio(
        name: "Engine Circuit 40:20", rounds: [20, 25, 30], work: 40, rest: 20, minPerRound: 1, unit: .rounds,
        details: ["40 sec work, 20 sec to switch. Stations in order: DB thruster, TRX row, KB swing, push-up, TRX mountain climber. Each 5 stations is one lap."], target: 80...90)
    static let bagIntervals = Cardio(
        name: "Heavy Bag Intervals", rounds: [6, 8, 10], work: 120, rest: 60, minPerRound: 3, unit: .rounds,
        details: ["2 min hard on the bag, 1 min easy. Keep your hands moving the whole 2 min: jab, cross, hooks, body shots. Hard enough you can only say a few words."], target: 80...90)
    static let hills = Cardio(
        name: "Hill Sprints", rounds: [6, 8, 10], work: 30, rest: 90, minPerRound: 2, unit: .rounds,
        details: ["30 sec hard on the treadmill at 8-10% incline (or a real hill), 90 sec easy walk."], target: 85...95)
    static let easy = Cardio(
        name: "Easy Aerobic", rounds: [30, 40, 45], work: nil, rest: nil, minPerRound: 1, unit: .min,
        details: ["Trails, treadmill walk on an incline or an easy jog. You should be able to talk the whole time (about 115-135 bpm)."], target: 60...70)
    static let swingEMOM = Cardio(
        name: "Swing EMOM", rounds: [8, 10, 12], work: 60, rest: 0, minPerRound: 1, unit: .rounds,
        details: ["Every minute on the minute: 15 KB swings, rest the rest of the minute. 35 or 50 lb bell."], target: 75...90)
    static let bagFinisher = Cardio(
        name: "Bag Finisher", rounds: [4, 5, 6], work: 60, rest: 30, minPerRound: 1.5, unit: .rounds,
        details: ["1 min all-out punching, 30 sec rest. Straight punches and hooks, keep the hands up."], target: 85...95)

    // Boxing
    static let technique = Cardio(
        name: "Technique Rounds", rounds: [5, 6, 6], work: 180, rest: 60, minPerRound: 4, unit: .rounds,
        details: [
            "Shadowbox 1 round first. R1 jab only, moving. R2 jab-cross (1-2). R3 1-2-3 (lead hook). R4 1-2 to the body, 1-2 to the head. R5 freestyle, sharp and light. Hands back to the face after every punch; breathe out on each.",
            "R1 1-2-3-2. R2 slip left, slip right, then 1-2. R3 lead hook to the body, lead hook to the head. R4 3-2-3. R5 1-2, roll under, 2-3-2. R6 freestyle with feints and angles.",
            "Fight pace. Every minute, 20 sec of nonstop 4-6 punch combos, then move and pick shots. Last 20 sec of each round: straight punches as fast as you can. Finish the round strong.",
        ], target: 70...85)
    static let longTechnique = Cardio(
        name: "Bag Rounds", rounds: [6, 8, 8], work: 180, rest: 60, minPerRound: 4, unit: .rounds,
        details: [
            "Shadowbox 2 rounds, then bag. Odd rounds: technique (1-2, 1-2-3, 1-1-2). Even rounds: move and counter. Stay on the balls of your feet.",
            "Odd rounds: power combos (2-3-2, 3-3-2, uppercut-hook). Even rounds: volume, keep punching the whole 3 min.",
            "Fight simulation: every round 3 min of real pace. Defense after every combo (slip, roll or step out).",
        ], target: 70...85)
    static let powerRounds = Cardio(
        name: "Power Rounds", rounds: [10, 12, 16], work: 30, rest: 30, minPerRound: 1, unit: .rounds,
        details: ["30 sec: the hardest shots you can throw with good form (crosses, hooks, uppercuts), turning the hips into each. 30 sec: bounce and shadowbox easy."], target: 85...95)
    static let roadwork = Cardio(
        name: "Roadwork", rounds: [20, 25, 30], work: nil, rest: nil, minPerRound: 1, unit: .min,
        details: ["Easy run or brisk incline walk at a pace you can talk at. Boxers' base."], target: 60...70)

    // MARK: Engine Strength

    static let engineStrength = Spec(
        doses: [
            .power: [Dose(5, 3, 3, 120), Dose(5, 2, 2, 120), Dose(5, 2, 2, 120)],
            .main: [Dose(4, 5, 5, 150), Dose(4, 3, 5, 180), Dose(4, 3, 3, 180)],
            .strength: [Dose(3, 6, 8, 120), Dose(3, 5, 6, 120), Dose(3, 5, 5, 120)],
            .accessory: [Dose(3, 8, 12, 60), Dose(3, 10, 12, 60), Dose(3, 8, 10, 60)],
        ],
        days: [
            3: [
                Day("Squat + 4×4", lower: true, lifts: [m("squat"), s("s1", "bench")],
                    pairs: [pair("bbrow", "reversecrunch")], engine: norwegian),
                Day("Power + Snatch", lifts: [p("power", "hangclean"), m("ohp", "ohp", "pushpress"), s("s1", "rdl")],
                    pairs: [pair("trxrow", "splitsq")], engine: snatch),
                Day("Deadlift + Circuit", lower: true, lifts: [m("deadlift"), s("s1", "dbincline")],
                    pairs: [pair("trxfacepull", "sideplank")], engine: circuit),
            ],
            4: [
                Day("Squat + 4×4", lower: true, lifts: [m("squat"), s("s1", "rdl")],
                    pairs: [pair("bulgarian", "trxbodysaw")], engine: norwegian),
                Day("Press + Bag", lifts: [m("bench"), s("s1", "bbrow")],
                    pairs: [pair("dbpress", "trxrow"), pair("curl", "ohtri")], engine: bagIntervals),
                Day("Power + Snatch", lower: true, lifts: [p("power", "hangclean", "hangclean", "powerclean"), m("deadlift")],
                    pairs: [pair("stepup", "trxfallout")], engine: snatch),
                Day("Upper + Circuit", lifts: [m("ohp", "ohp", "pushpress"), s("s1", "dbincline")],
                    pairs: [pair("trxfacepull", "hammer")], engine: circuit),
            ],
            5: [
                Day("Squat + 4×4", lower: true, lifts: [m("squat"), s("s1", "rdl")],
                    pairs: [pair("bulgarian", "trxbodysaw")], engine: norwegian),
                Day("Press + Bag", lifts: [m("bench"), s("s1", "bbrow")],
                    pairs: [pair("dbpress", "trxrow"), pair("curl", "ohtri")], engine: bagIntervals),
                Day("Power + Snatch", lower: true, lifts: [p("power", "hangclean", "hangclean", "powerclean"), m("deadlift")],
                    pairs: [pair("stepup", "trxfallout")], engine: snatch),
                Day("Upper + Circuit", lifts: [m("ohp", "ohp", "pushpress"), s("s1", "dbincline")],
                    pairs: [pair("trxfacepull", "hammer")], engine: circuit),
                Day("Aerobic Base + Core", lifts: [],
                    pairs: [pair("trxoblique", "hipdip"), pair("kbwindmill", "suitcase")], engine: easy),
            ],
        ])

    // MARK: Define 45

    static let define45 = Spec(
        doses: [
            .power: [Dose(3, 3, 3, 120), Dose(4, 3, 3, 120), Dose(4, 2, 3, 120)],
            .main: [Dose(4, 6, 8, 150), Dose(4, 5, 6, 150), Dose(3, 4, 6, 180)],
            .strength: [Dose(3, 8, 10, 90), Dose(3, 8, 10, 90), Dose(3, 6, 8, 90)],
            .accessory: [Dose(3, 10, 15, 60), Dose(4, 10, 12, 60), Dose(3, 12, 15, 45)],
        ],
        days: [
            3: [
                Day("Full Body A", lower: true, lifts: [m("squat"), s("s1", "bench")],
                    pairs: [pair("bbrow", "lateral"), pair("curl", "ohtri")], finisher: hills),
                Day("Full Body B", lower: true, lifts: [m("deadlift"), s("s1", "ohp")],
                    pairs: [pair("trxrow", "trxchestfly"), pair("reardelt", "trxfallout")], finisher: bagFinisher),
                Day("Full Body C", lifts: [m("incline"), s("s1", "bulgarian")],
                    pairs: [pair("dbrow", "arnold"), pair("hammer", "skull"), pair("vup", "woodchop")], finisher: swingEMOM),
            ],
            4: [
                Day("Upper A", lifts: [m("bench"), s("s1", "bbrow")],
                    pairs: [pair("dbincline", "trxfacepull"), pair("curl", "ohtri"), pair("trxchestfly", "legraise")], finisher: bagFinisher),
                Day("Lower A", lower: true, lifts: [m("squat"), s("s1", "rdl")],
                    pairs: [pair("splitsq", "trxhamcurl"), pair("trxbodysaw", "hipdip")], finisher: hills),
                Day("Upper B", lifts: [m("ohp"), s("s1", "pendlay")],
                    pairs: [pair("dbfloor", "lateral"), pair("hammer", "skull"), pair("trxyfly", "reardelt")]),
                Day("Lower B", lower: true, lifts: [p("power", "hangclean"), m("deadlift"), s("s1", "gobletsq")],
                    pairs: [pair("hipthrust", "russiantwist")], finisher: swingEMOM),
            ],
            5: [
                Day("Upper A", lifts: [m("bench"), s("s1", "bbrow")],
                    pairs: [pair("dbincline", "trxfacepull"), pair("curl", "ohtri"), pair("trxchestfly", "legraise")], finisher: bagFinisher),
                Day("Lower A", lower: true, lifts: [m("squat"), s("s1", "rdl")],
                    pairs: [pair("splitsq", "trxhamcurl"), pair("trxbodysaw", "hipdip")], finisher: hills),
                Day("Upper B", lifts: [m("ohp"), s("s1", "pendlay")],
                    pairs: [pair("dbfloor", "lateral"), pair("hammer", "skull"), pair("trxyfly", "reardelt")]),
                Day("Lower B", lower: true, lifts: [p("power", "hangclean"), m("deadlift"), s("s1", "gobletsq")],
                    pairs: [pair("hipthrust", "russiantwist")], finisher: swingEMOM),
                Day("Arms, Delts + Engine", lifts: [],
                    pairs: [pair("inclinecurl", "skull"), pair("lateral", "reardelt"), pair("trxchestfly", "trxhighrow")],
                    engine: norwegian),
            ],
        ])

    // MARK: Strength & Boxing

    static let strengthBoxing = Spec(
        doses: [
            .power: [Dose(5, 3, 3, 120), Dose(5, 2, 3, 120), Dose(5, 2, 2, 120)],
            .main: [Dose(4, 5, 5, 150), Dose(4, 3, 5, 150), Dose(4, 3, 3, 180)],
            .strength: [Dose(3, 6, 8, 90), Dose(3, 6, 8, 90), Dose(3, 5, 6, 90)],
            .accessory: [Dose(3, 10, 12, 60), Dose(3, 10, 12, 60), Dose(3, 8, 10, 45)],
        ],
        days: [
            3: [
                Day("Strength + Technique", lower: true, lifts: [p("power", "powerclean"), m("squat"), s("s1", "bench")],
                    pairs: [pair("trxrow", "sideplank")], engine: technique, engineBlock: .box),
                Day("Press + Power Rounds", lifts: [m("pushpress"), s("s1", "rdl")],
                    pairs: [pair("dbrow", "woodchop")], engine: powerRounds, engineBlock: .box),
                Day("Deadlift + Fight Rounds", lower: true, lifts: [m("deadlift"), s("s1", "floorpress")],
                    pairs: [pair("bulgarian", "russiantwist")], engine: technique, engineBlock: .box),
            ],
            4: [
                Day("Lower Strength + Technique", lower: true, lifts: [p("power", "hangclean"), m("squat"), s("s1", "rdl")],
                    pairs: [pair("splitsq", "sideplank")], engine: technique, engineBlock: .box),
                Day("Upper Strength + Power Rounds", lifts: [m("bench"), s("s1", "bbrow")],
                    pairs: [pair("dbpress", "trxrow"), pair("trxfacepull", "hammer")], engine: powerRounds, engineBlock: .box),
                Day("Power + Fight Rounds", lower: true, lifts: [p("power", "powerclean"), m("deadlift")],
                    pairs: [pair("trxpowerpull", "woodchop")], engine: technique, engineBlock: .box),
                Day("Upper + Roadwork", lifts: [m("pushpress"), s("s1", "pendlay")],
                    pairs: [pair("dbincline", "dbrow"), pair("trxyfly", "russiantwist")], engine: roadwork),
            ],
            5: [
                Day("Lower Strength + Technique", lower: true, lifts: [p("power", "hangclean"), m("squat"), s("s1", "rdl")],
                    pairs: [pair("splitsq", "sideplank")], engine: technique, engineBlock: .box),
                Day("Upper Strength + Power Rounds", lifts: [m("bench"), s("s1", "bbrow")],
                    pairs: [pair("dbpress", "trxrow"), pair("trxfacepull", "hammer")], engine: powerRounds, engineBlock: .box),
                Day("Power + Fight Rounds", lower: true, lifts: [p("power", "powerclean"), m("deadlift")],
                    pairs: [pair("trxpowerpull", "woodchop")], engine: technique, engineBlock: .box),
                Day("Upper + Roadwork", lifts: [m("pushpress"), s("s1", "pendlay")],
                    pairs: [pair("dbincline", "dbrow"), pair("trxyfly", "russiantwist")], engine: roadwork),
                Day("Bag Day + Core", lifts: [],
                    pairs: [pair("trxbodysaw", "bicycle"), pair("suitcase", "trxoblique")],
                    engine: longTechnique, engineBlock: .box),
            ],
        ])

    // MARK: Screen Ready (the actor cut)

    static let absBurner = Cardio(
        name: "Abs Burner", rounds: [8, 10, 12], work: 40, rest: 20, minPerRound: 1, unit: .rounds,
        details: ["40 sec on, 20 off, rotating: V-ups, bicycle crunch, plank shoulder taps, reverse crunch. Quality reps, ribs down."], target: 65...80)
    static let inclineWalk = Cardio(
        name: "Incline Walk", rounds: [30, 35, 40], work: nil, rest: nil, minPerRound: 1, unit: .min,
        details: ["Treadmill at 10-12% incline, a brisk walk you could talk through. Burns fat without eating into recovery."], target: 60...70)

    static let screenReady = Spec(
        doses: [
            .power: [Dose(3, 3, 3, 120), Dose(3, 3, 3, 120), Dose(3, 3, 3, 120)],
            .main: [Dose(4, 6, 8, 120), Dose(4, 6, 8, 105), Dose(3, 6, 8, 90)],
            .strength: [Dose(3, 8, 10, 90), Dose(3, 8, 12, 75), Dose(3, 10, 12, 60)],
            .accessory: [Dose(3, 10, 15, 60), Dose(3, 12, 15, 45), Dose(4, 12, 15, 30)],
        ],
        days: [
            3: [
                Day("Chest, Shoulders + Abs", lifts: [m("incline"), s("s1", "dbincline")],
                    pairs: [pair("trxchestfly", "lateral"), pair("bbcurl", "skull"), pair("vup", "trxoblique")],
                    finisher: absBurner),
                Day("Legs + Back", lower: true, lifts: [m("squat"), s("s1", "bbrow")],
                    pairs: [pair("bulgarian", "trxhighrow"), pair("hipthrust", "legraise")], finisher: hills),
                Day("Full Body + Arms", lower: true, lifts: [p("power", "hangclean"), m("deadlift"), s("s1", "ohp")],
                    pairs: [pair("trxrow", "trxchestfly"), pair("hammer", "trxtricep"), pair("trxfallout", "russiantwist")],
                    finisher: bagFinisher),
            ],
            4: [
                Day("Chest, Shoulders + Abs", lifts: [m("incline"), s("s1", "dbincline")],
                    pairs: [pair("trxchestfly", "lateral"), pair("arnold", "reardelt"), pair("vup", "trxoblique")],
                    finisher: absBurner),
                Day("Legs + Back", lower: true, lifts: [m("squat"), s("s1", "bbrow")],
                    pairs: [pair("bulgarian", "trxhighrow"), pair("hipthrust", "legraise")], finisher: hills),
                Day("Arms, Delts + Abs", lifts: [m("ohp"), s("s1", "dbfloor")],
                    pairs: [pair("bbcurl", "skull"), pair("hammer", "trxtricep"), pair("trxfallout", "bicycle")],
                    finisher: absBurner),
                Day("Full Body", lower: true, lifts: [p("power", "hangclean"), m("deadlift"), s("s1", "bench")],
                    pairs: [pair("trxrow", "trxchestfly"), pair("lateral", "russiantwist")], finisher: bagFinisher),
            ],
            5: [
                Day("Chest, Shoulders + Abs", lifts: [m("incline"), s("s1", "dbincline")],
                    pairs: [pair("trxchestfly", "lateral"), pair("arnold", "reardelt"), pair("vup", "trxoblique")],
                    finisher: absBurner),
                Day("Legs + Back", lower: true, lifts: [m("squat"), s("s1", "bbrow")],
                    pairs: [pair("bulgarian", "trxhighrow"), pair("hipthrust", "legraise")], finisher: hills),
                Day("Arms, Delts + Abs", lifts: [m("ohp"), s("s1", "dbfloor")],
                    pairs: [pair("bbcurl", "skull"), pair("hammer", "trxtricep"), pair("trxfallout", "bicycle")],
                    finisher: absBurner),
                Day("Full Body", lower: true, lifts: [p("power", "hangclean"), m("deadlift"), s("s1", "bench")],
                    pairs: [pair("trxrow", "trxchestfly"), pair("lateral", "russiantwist")], finisher: bagFinisher),
                Day("Pump + Incline Walk", lifts: [],
                    pairs: [pair("trxchestfly", "trxhighrow"), pair("inclinecurl", "ohtri"), pair("lateral", "hollowrock")],
                    engine: inclineWalk),
            ],
        ])

    // MARK: Agent Circuits (about 45 minutes: heavy lift, then a circuit)

    static let kbCircuit = Cardio(
        name: "Kettlebell Circuit", rounds: [15, 20, 25], work: 45, rest: 15, minPerRound: 1, unit: .rounds,
        details: ["45 sec work, 15 sec to switch, 5 stations per lap: KB swing, goblet squat, KB clean & press (switch arms each lap), renegade row, TRX atomic push-up."], target: 80...90)
    static let trxCircuit = Cardio(
        name: "TRX & Bodyweight Circuit", rounds: [15, 20, 25], work: 45, rest: 15, minPerRound: 1, unit: .rounds,
        details: ["45 sec work, 15 sec to switch, 5 stations per lap: TRX row, push-up, reverse lunge, TRX pike, burpee."], target: 75...90)
    static let dbComplex = Cardio(
        name: "Dumbbell Complex", rounds: [4, 5, 6], work: 120, rest: 75, minPerRound: 3.25, unit: .rounds,
        details: ["One round = 6 of each without putting the bells down: DB hang clean, front squat, push press, renegade row, reverse lunge each leg. Rest 75 sec between rounds."], target: 80...90)
    static let agentBag = Cardio(
        name: "Bag + Carry Circuit", rounds: [12, 16, 20], work: 60, rest: 15, minPerRound: 1.25, unit: .rounds,
        details: ["60 sec stations, 15 sec to move, 4 per lap: heavy bag, KB suitcase carry (switch hands halfway), mountain climbers, bag again."], target: 80...90)

    static let agentCircuits = Spec(
        doses: [
            .power: [Dose(4, 5, 5, 90), Dose(5, 5, 5, 90), Dose(5, 3, 3, 90)],
            .main: [Dose(4, 5, 5, 150), Dose(4, 4, 6, 150), Dose(3, 3, 5, 150)],
            .strength: [Dose(3, 6, 8, 90), Dose(3, 6, 8, 90), Dose(3, 6, 8, 75)],
            .accessory: [Dose(2, 8, 12, 45), Dose(3, 10, 12, 45), Dose(3, 10, 15, 30)],
        ],
        days: [
            3: [
                Day("Lower Power", lower: true, lifts: [m("squat")],
                    pairs: [pair("trxpistol", "trxfallout")], engine: kbCircuit),
                Day("Upper Push-Pull", lifts: [m("bench"), s("s1", "pendlay")],
                    pairs: [pair("trxchestfly", "trxhighrow")], engine: trxCircuit),
                Day("Hinge + Press", lower: true, lifts: [m("deadlift"), s("s1", "pushpress")],
                    pairs: [pair("trxpowerpull", "woodchop")], engine: dbComplex),
            ],
            4: [
                Day("Lower Power", lower: true, lifts: [m("squat")],
                    pairs: [pair("trxpistol", "trxfallout")], engine: kbCircuit),
                Day("Upper Push-Pull", lifts: [m("bench"), s("s1", "pendlay")],
                    pairs: [pair("trxchestfly", "trxhighrow")], engine: trxCircuit),
                Day("Hinge + Carry", lower: true, lifts: [m("deadlift"), s("s1", "hipthrust")],
                    pairs: [pair("suitcase", "copenhagen")], engine: dbComplex),
                Day("Athletic", lifts: [p("power", "dbsnatch"), m("pushpress")],
                    pairs: [pair("trxpowerpull", "woodchop")], engine: agentBag),
            ],
            5: [
                Day("Lower Power", lower: true, lifts: [m("squat")],
                    pairs: [pair("trxpistol", "trxfallout")], engine: kbCircuit),
                Day("Upper Push-Pull", lifts: [m("bench"), s("s1", "pendlay")],
                    pairs: [pair("trxchestfly", "trxhighrow")], engine: trxCircuit),
                Day("Hinge + Carry", lower: true, lifts: [m("deadlift"), s("s1", "hipthrust")],
                    pairs: [pair("suitcase", "copenhagen")], engine: dbComplex),
                Day("Athletic", lifts: [p("power", "dbsnatch"), m("pushpress")],
                    pairs: [pair("trxpowerpull", "woodchop")], engine: agentBag),
                Day("Recovery Run + Core", lifts: [],
                    pairs: [pair("trxbodysaw", "hipdip"), pair("kbwindmill", "shouldertap")], engine: easy),
            ],
        ])

    static func spec(_ id: ProgramID) -> Spec? {
        switch id {
        case .hybrid12: return nil
        case .engineStrength: return engineStrength
        case .define45: return define45
        case .strengthBoxing: return strengthBoxing
        case .screenReady: return screenReady
        case .agentCircuits: return agentCircuits
        }
    }

    static let slots: [Slot] = [.A, .B, .C, .D, .E]

    /// Day plans for a program and days-a-week (empty for Hybrid 12).
    public static func days(_ id: ProgramID, days: Int) -> [Day] {
        guard let spec = spec(id) else { return [] }
        return spec.days[days] ?? spec.days[id.defaultDays] ?? []
    }

    static func day(_ slot: Slot, program: ProgramID, days count: Int) -> Day? {
        guard let i = slots.firstIndex(of: slot) else { return nil }
        let list = days(program, days: count)
        return i < list.count ? list[i] : nil
    }

    public static func order(_ id: ProgramID, days count: Int) -> [Slot] {
        guard id != .hybrid12 else { return Program.order }
        return Array(slots.prefix(days(id, days: count).count))
    }

    public static func lower(_ id: ProgramID, days count: Int) -> [Slot] {
        guard id != .hybrid12 else { return Program.lower }
        return order(id, days: count).filter { day($0, program: id, days: count)?.lower == true }
    }

    public static func name(_ slot: Slot, program: ProgramID, days count: Int) -> String {
        guard program != .hybrid12 else { return Program.plan(slot).name }
        return day(slot, program: program, days: count)?.name ?? "Day"
    }

    // MARK: Building a session

    static func build(slot: Slot, context: SessionContext, week: ProgramWeek, catalog: Catalog) -> Session {
        let program = context.program
        guard let spec = spec(program), let day = day(slot, program: program, days: context.days) else {
            return Session(slot: slot, title: "Rest day", week: week, readiness: context.readiness, blocks: [])
        }
        let phase = week.phase
        let beat = context.readiness == .beat
        let great = context.readiness == .great
        var blocks: [SessionBlock] = []

        func dose(_ role: Role) -> Dose { spec.doses[role]![phase.rawValue] }
        func range(_ ex: Exercise, _ d: Dose) -> (Int, Int) {
            switch ex.unit {
            case .sec: return holds[phase.rawValue]
            case .yd: return (Program.carryYards, Program.carryYards)
            default: return (d.low, d.high)
            }
        }
        func exercise(_ key: String, _ planned: String) -> Exercise? {
            if let swap = context.swaps[key], let ex = catalog.exercise(swap) { return ex }
            return catalog.exercise(planned)
        }

        // Get strong: power, main, strength lifts.
        var strong: [SessionItem] = []
        var strengthIndex = 0
        for lift in day.lifts {
            guard let ex = exercise(lift.key, lift.id(phase)) else { continue }
            let d = dose(lift.role)
            var sets = d.sets
            if lift.role == .main || lift.role == .power {
                if lift.role == .main && ex.id == "deadlift" { sets -= 1 }   // heavy pulls: one set fewer
                if great { sets += 1 }
                if beat || week.isDeload { sets -= 1 }
            } else if week.isDeload || beat {
                sets -= 1
            }
            let (low, high) = range(ex, d)
            let tag: String
            switch lift.role {
            case .power: tag = "P"
            case .main: tag = "A"
            default: strengthIndex += 1; tag = "S\(strengthIndex)"
            }
            strong.append(SessionItem(
                key: lift.key, tag: tag, kind: lift.role == .main ? .main : .accessory,
                exerciseID: ex.id, name: ex.name, equipment: ex.eq, unit: ex.unit, side: ex.side,
                sets: max(lift.role == .main ? 2 : 1, sets), low: low, high: high, restSeconds: d.rest,
                detail: ex.cue))
        }
        if !strong.isEmpty { blocks.append(SessionBlock(kind: .getStrong, items: strong)) }

        // Supersets ("Build the look"). Beat-up days keep only the first pair.
        let acc = dose(.accessory)
        let accSets = max(1, acc.sets - (week.isDeload ? 1 : 0))
        let letters = Array(strong.isEmpty ? "ABCDEF" : "BCDEFG")
        var pairItems: [SessionItem] = []
        for (pi, pairIDs) in day.pairs.enumerated() where !(beat && pi > 0) {
            for (ci, ids) in pairIDs.enumerated() {
                let key = "p\(pi)c\(ci)"
                let planned = ids.count == 3 ? ids[phase.rawValue] : ids[0]
                guard let ex = exercise(key, planned) else { continue }
                let (low, high) = range(ex, acc)
                pairItems.append(SessionItem(
                    key: key, tag: "\(letters[min(letters.count - 1, pi)])\(ci + 1)",
                    kind: .accessory, exerciseID: ex.id, name: ex.name, equipment: ex.eq, unit: ex.unit, side: ex.side,
                    sets: accSets, low: low, high: high, restSeconds: acc.rest, detail: ex.cue,
                    pair: pi, position: ci))
            }
        }
        if !pairItems.isEmpty { blocks.append(SessionBlock(kind: .buildTheLook, items: pairItems)) }

        // Conditioning.
        func cardioItem(_ c: Cardio, key: String, kind: ItemKind) -> SessionItem {
            var rounds = c.rounds[phase.rawValue]
            if week.isDeload { rounds = (rounds * 3 + 3) / 4 }   // about 75%
            if beat { rounds = halfUp(rounds) }
            var item = SessionItem(
                key: key, tag: "", kind: kind, exerciseID: nil, name: c.name, equipment: nil, unit: c.unit,
                sets: 1, low: rounds, high: rounds, restSeconds: 0, rounds: rounds, minutesPerRound: c.minPerRound,
                detail: c.detail(phase), intervalWork: c.work, intervalRest: c.rest)
            item.canSwap = false
            if let t = c.target { item.hrLow = t.lowerBound; item.hrHigh = t.upperBound }
            return item
        }
        if let e = day.engine {
            blocks.append(SessionBlock(kind: day.engineBlock, items: [cardioItem(e, key: "engine", kind: .engine)]))
        }
        if let f = day.finisher, !beat {
            blocks.append(SessionBlock(kind: .burnIt, items: [cardioItem(f, key: "finisher", kind: .finisher)]))
        }

        return Session(slot: slot, title: day.name, week: week, readiness: context.readiness, blocks: blocks)
    }
}
