import Foundation
import HealthKit
import Hybrid12Engine

/// Writes finished sessions to Apple Health so they show in the Fitness app.
final class HealthService {
    static let shared = HealthService()
    private let store = HKHealthStore()

    /// VO2 max readings in Apple Health since `start`, from any app that writes them
    /// (WHOOP, an Apple Watch...). Asks for permission the first time. Nil if Health isn't available.
    func vo2Max(since start: Date) async -> [VO2Reading]? {
        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKQuantityType.quantityType(forIdentifier: .vo2Max) else { return nil }
        do {
            try await store.requestAuthorization(toShare: [], read: [type])
            let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
            let query = HKSampleQueryDescriptor(predicates: [.quantitySample(type: type, predicate: predicate)],
                                                sortDescriptors: [SortDescriptor(\.startDate)])
            let unit = HKUnit(from: "ml/kg*min")
            return try await query.result(for: store).map { s in
                VO2Reading(id: s.uuid.uuidString, date: s.startDate, value: s.quantity.doubleValue(for: unit),
                           source: s.sourceRevision.source.name)
            }
        } catch {
            print("Could not read VO2 max from Health: \(error)")
            return nil
        }
    }

    /// Asks for permission the first time; after a "no" it quietly does nothing.
    func save(_ record: WorkoutRecord) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let workoutType = HKObjectType.workoutType()
        do {
            try await store.requestAuthorization(toShare: [workoutType], read: [])
            guard store.authorizationStatus(for: workoutType) == .sharingAuthorized else { return }

            let config = HKWorkoutConfiguration()
            switch record.kind {
            case .strength:
                config.activityType = .traditionalStrengthTraining
                config.locationType = .indoor
            case .running:
                config.activityType = .running
                config.locationType = .unknown
            }
            let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
            try await builder.beginCollection(at: record.start)
            try await builder.addMetadata([HKMetadataKeyWorkoutBrandName: "Hybrid 12 · \(record.title)"])
            try await builder.endCollection(at: record.end)
            _ = try await builder.finishWorkout()
        } catch {
            print("Could not save the workout to Health: \(error)")
        }
    }
}
