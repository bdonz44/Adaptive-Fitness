import Foundation
import HealthKit
import Hybrid12Engine

/// Writes finished sessions to Apple Health so they show in the Fitness app.
final class HealthService {
    static let shared = HealthService()
    private let store = HKHealthStore()

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
