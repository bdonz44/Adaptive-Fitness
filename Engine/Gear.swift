import Foundation

/// Adaptive 7: the equipment you own. Suggestions snap to it, the kettlebell button cycles
/// your bells, and exercises needing gear you don't have are swapped out or hidden.
/// `.standard` is the home gym the program was written for.
public struct GearProfile: Codable, Equatable, Sendable {
    public var barbell: Bool
    /// Heaviest total you can load on the bar (nil: no limit).
    public var barbellMax: Double?
    /// Smallest plate you own: barbell weights move in steps of two of these.
    public var smallestPlate: Double
    public var dumbbells: [Double]
    public var kettlebells: [Double]
    public var bench: Bool
    public var trx: Bool
    public var bag: Bool
    public var treadmill: Bool
    public var pullupBar: Bool
    public var ropes: Bool

    public init(barbell: Bool = true, barbellMax: Double? = nil, smallestPlate: Double = 2.5,
                dumbbells: [Double] = [5, 10, 15, 20, 25, 30, 35], kettlebells: [Double] = [20, 35, 50],
                bench: Bool = true, trx: Bool = true, bag: Bool = true, treadmill: Bool = true, pullupBar: Bool = true,
                ropes: Bool = true) {
        self.barbell = barbell; self.barbellMax = barbellMax; self.smallestPlate = smallestPlate
        self.dumbbells = dumbbells.sorted(); self.kettlebells = kettlebells.sorted()
        self.bench = bench; self.trx = trx; self.bag = bag; self.treadmill = treadmill; self.pullupBar = pullupBar
        self.ropes = ropes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = GearProfile.standard
        barbell = try c.decodeIfPresent(Bool.self, forKey: .barbell) ?? d.barbell
        barbellMax = try c.decodeIfPresent(Double.self, forKey: .barbellMax)
        smallestPlate = try c.decodeIfPresent(Double.self, forKey: .smallestPlate) ?? d.smallestPlate
        dumbbells = (try c.decodeIfPresent([Double].self, forKey: .dumbbells) ?? d.dumbbells).sorted()
        kettlebells = (try c.decodeIfPresent([Double].self, forKey: .kettlebells) ?? d.kettlebells).sorted()
        bench = try c.decodeIfPresent(Bool.self, forKey: .bench) ?? d.bench
        trx = try c.decodeIfPresent(Bool.self, forKey: .trx) ?? d.trx
        bag = try c.decodeIfPresent(Bool.self, forKey: .bag) ?? d.bag
        treadmill = try c.decodeIfPresent(Bool.self, forKey: .treadmill) ?? d.treadmill
        pullupBar = try c.decodeIfPresent(Bool.self, forKey: .pullupBar) ?? d.pullupBar
        ropes = try c.decodeIfPresent(Bool.self, forKey: .ropes) ?? d.ropes
    }

    public static let standard = GearProfile()
    public static let barbellBar: Double = 45

    // MARK: Snapping weights to what you own

    public func barbellWeight(_ w: Double) -> Double {
        let step = max(1, smallestPlate * 2)
        var x = max(Self.barbellBar, (w / step).rounded() * step)
        if let top = barbellMax { x = min(x, max(Self.barbellBar, top)) }
        return x
    }

    public func dumbbell(_ w: Double) -> Double { Self.nearest(w, in: dumbbells) ?? (w / 5).rounded() * 5 }
    public var dumbbellMax: Double { dumbbells.last ?? 0 }

    /// Halfway between two bells goes to the lighter one (spec: 43 and up = 50, so 42.5 is 35).
    public func bell(_ w: Double) -> Double { Self.nearest(w, in: kettlebells, tiesLighter: true) ?? (w / 5).rounded() * 5 }
    public var heaviestBell: Double { kettlebells.last ?? 0 }

    /// The kettlebell button: next bell up, wrapping to the lightest.
    public func nextBell(after w: Double) -> Double {
        guard !kettlebells.isEmpty else { return w }
        let current = bell(w)
        return kettlebells.first { $0 > current } ?? kettlebells[0]
    }

    public func heavierBell(than w: Double) -> Double? { kettlebells.first { $0 > bell(w) } }
    public func lighterBell(than w: Double) -> Double? { kettlebells.last { $0 < bell(w) } }

    static func nearest(_ w: Double, in list: [Double], tiesLighter: Bool = false) -> Double? {
        list.min { abs($0 - w) == abs($1 - w) ? (tiesLighter ? $0 < $1 : $0 > $1) : abs($0 - w) < abs($1 - w) }
    }

    // MARK: Which exercises you can do

    /// Exercises done lying or sitting on a bench (or with a foot or arm on one).
    public static let benchExercises: Set<String> = [
        "bench", "incline", "dbincline", "dbfly", "skull", "inclinecurl", "dbpress", "csrow", "dbrow",
        "hipthrust", "bulgarian", "stepup", "copenhagen", "arnold",
    ]

    public func has(_ ex: Exercise) -> Bool {
        if ex.category == "trx" { return trx }
        if ex.category == "pull" { return pullupBar }
        if Self.benchExercises.contains(ex.id) && !bench { return false }
        switch ex.eq {
        case .bb: return barbell
        case .db: return !dumbbells.isEmpty
        case .kb: return !kettlebells.isEmpty
        case .bw: return true
        }
    }
}
