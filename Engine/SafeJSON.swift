import Foundation

/// JSON coding for everything the app saves.
///
/// A plain `JSONEncoder` throws on a Double that is NaN or infinite, so one bad
/// number (a typo, a division by zero) would make a whole record fail to save.
/// These coders write such numbers as strings instead, and read them back.
public enum SafeJSON {
    private static let floats = (positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")

    public static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: floats.positiveInfinity, negativeInfinity: floats.negativeInfinity, nan: floats.nan)
        return e
    }

    public static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: floats.positiveInfinity, negativeInfinity: floats.negativeInfinity, nan: floats.nan)
        return d
    }

    /// Nil only if the value can't be encoded at all. Callers must then keep the old data.
    public static func encode<T: Encodable>(_ value: T) -> Data? {
        try? encoder().encode(value)
    }

    public static func decode<T: Decodable>(_ type: T.Type, _ data: Data) -> T? {
        guard !data.isEmpty else { return nil }
        return try? decoder().decode(type, from: data)
    }
}

extension Double {
    /// A weight, rep count or measurement a person could really have typed: finite and not negative.
    public var isUsableAmount: Bool { isFinite && self >= 0 }
}
