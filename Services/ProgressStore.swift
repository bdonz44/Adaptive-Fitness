import Foundation
import Observation
import UIKit
import Hybrid12Engine

/// Progress photos and tape measurements, kept on this phone in Application Support/Progress.
/// Photos can also be copied to the Photos library (backed up by iCloud Photos).
@Observable
final class ProgressStore {
    static let saveToLibraryKey = "photos.saveToLibrary"

    private(set) var photos: [ProgressPhoto] = []
    private(set) var measurements: [BodyMeasurement] = []

    @ObservationIgnored private let folder: URL
    @ObservationIgnored private var cache: [String: UIImage] = [:]

    var saveToLibrary: Bool {
        get { access(keyPath: \.saveToLibrary); return UserDefaults.standard.object(forKey: Self.saveToLibraryKey) as? Bool ?? true }
        set { withMutation(keyPath: \.saveToLibrary) { UserDefaults.standard.set(newValue, forKey: Self.saveToLibraryKey) } }
    }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        folder = base.appendingPathComponent("Progress", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        photos = load([ProgressPhoto].self, "photos.json") ?? []
        measurements = load([BodyMeasurement].self, "measurements.json") ?? []
    }

    // MARK: Photos

    func addPhoto(_ image: UIImage, pose: PhotoPose, date: Date = Date()) {
        let resized = Self.resize(image, maxSide: 1800)
        let photo = ProgressPhoto(date: date, pose: pose, file: "\(Int(date.timeIntervalSince1970))-\(pose.rawValue).jpg")
        guard let data = resized.jpegData(compressionQuality: 0.85),
              (try? data.write(to: folder.appendingPathComponent(photo.file), options: .atomic)) != nil else { return }
        cache[photo.file] = resized
        photos.append(photo)
        save(photos, "photos.json")
        if saveToLibrary { UIImageWriteToSavedPhotosAlbum(resized, nil, nil, nil) }
    }

    func deletePhoto(_ photo: ProgressPhoto) {
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(photo.file))
        cache[photo.file] = nil
        photos.removeAll { $0.id == photo.id }
        save(photos, "photos.json")
    }

    func image(_ photo: ProgressPhoto?) -> UIImage? {
        guard let photo else { return nil }
        if let hit = cache[photo.file] { return hit }
        let img = UIImage(contentsOfFile: folder.appendingPathComponent(photo.file).path)
        cache[photo.file] = img
        return img
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

    static func resize(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
    }
}
