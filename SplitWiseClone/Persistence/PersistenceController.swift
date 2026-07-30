//
//  PersistenceController.swift
//  SplitWiseClone
//
//  Core Data stack backed by NSPersistentCloudKitContainer for
//  offline-first, multi-device sync. Uses history tracking + remote
//  change notifications so local edits sync automatically when a
//  network connection is available, and the app works fully offline
//  otherwise (Core Data is the local source of truth).
//

import CoreData

final class PersistenceController {
    static let shared = PersistenceController()

    /// In-memory store used by SwiftUI previews and unit tests.
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        // TODO: seed sample Group / Member / Expense records here for previews
        return controller
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        // NOTE: The .xcdatamodeld file itself must be created in Xcode's
        // Core Data model editor (it's a binary-ish bundle format, not
        // hand-writable). Model name below must match the file you create:
        // "SplitWiseClone.xcdatamodeld" with entities Group, Member,
        // Expense, ExpenseSplit, Settlement.
        container = NSPersistentCloudKitContainer(name: "SplitWiseClone")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("No persistent store description found.")
            }
            // Enable history tracking + remote change notifications, required
            // for NSPersistentCloudKitContainer to sync correctly across devices.
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // Replace with real logging / user-facing error handling.
                fatalError("Unresolved Core Data + CloudKit error: \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func save() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            // Replace with real error handling.
            print("Failed to save context: \(error)")
        }
    }
}
