#if DEBUG
import CoreData
import SwiftData

/// Debug builds only: pushes the SwiftData model to the CloudKit *Development*
/// environment (launch argument `-initCloudKitSchema`, with the device or
/// simulator signed in to iCloud). Then deploy it to Production in the CloudKit
/// Console so TestFlight builds can sync.
enum CloudKitSchema {
    static func initialize(schema: Schema, containerID: String) {
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .private(containerID))
        let description = NSPersistentStoreDescription(url: config.url)
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: containerID)
        description.shouldAddStoreAsynchronously = false

        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: Schema12.models) else {
            print("CloudKit schema: could not build the model")
            return
        }
        let container = NSPersistentCloudKitContainer(name: "Hybrid12", managedObjectModel: model)
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError {
            print("CloudKit schema: store failed to load: \(loadError)")
            return
        }
        do {
            try container.initializeCloudKitSchema()
            print("CloudKit schema: initialized in Development")
        } catch {
            print("CloudKit schema: failed: \(error)")
        }
        for store in container.persistentStoreCoordinator.persistentStores {
            try? container.persistentStoreCoordinator.remove(store)
        }
    }
}
#endif
