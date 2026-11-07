import Foundation
import Observation
import Hybrid12Engine

/// Chest and arm measurements, kept on this phone in Application Support/Progress.
@Observable
final class ProgressStore {
    private(set) var measurements: [BodyMeasurement] = []

    @ObservationIgnored private let folder: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        folder = base.appendingPathComponent("Progress", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        measurements = load([BodyMeasurement].self, "measurements.json") ?? []
    }

    // MARK: Measurements

    func points(_ part: BodyPart) -> [BodyMeasurement] {
        measurements.filter { $0.part == part }.sorted { $0.date < $1.date }
    }

    func addMeasurement(_ inches: Double, part: BodyPart, date: Date = Date()) {
        measurements.append(BodyMeasurement(date: date, part: part, inches: inches))
        save(measurements, "measurements.json")
    }

    func removeMeasurement(_ m: BodyMeasurement) {
        measurements.removeAll { $0 == m }
        save(measurements, "measurements.json")
    }

    // MARK: Files

    private func load<T: Decodable>(_ type: T.Type, _ name: String) -> T? {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent(name)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, _ name: String) {
        if let data = try? JSONEncoder().encode(value) {
            try? data.write(to: folder.appendingPathComponent(name), options: .atomic)
        }
    }
}
