//
//  PersistenceController.swift
//  SplitWiseClone
//
//  Core Data stack backed by NSPersistentCloudKitContainer for
//  offline-first, multi-device sync. Two stores:
//   - private: the user's own groups (the original store file, so existing
//     data survives the upgrade), mirrored to their private CloudKit DB.
//   - shared: groups other iCloud users have shared with this user.
//  Core Data is always the local source of truth; CloudKit catches up
//  whenever a network connection is available.
//

import CloudKit
import CoreData

final class PersistenceController {
    static let cloudKitContainerID = "iCloud.com.dhyan.SplitWiseClone"

    static let shared = PersistenceController()

    /// True for UI tests (-uiTesting) and for unit tests hosted in the app, so
    /// neither ever touches the real store or the signed-in account.
    static let isTesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    /// The stack this launch should use. -demoData launches with the seeded
    /// in-memory preview store (UI tests use it for README screenshots);
    /// other tests get a clean in-memory store. App Intents read this too, so
    /// Siri writes land in the same store as the UI.
    static let current: PersistenceController = {
        if ProcessInfo.processInfo.arguments.contains("-demoData") { return .preview }
        if isTesting { return PersistenceController(inMemory: true) }
        return .shared
    }()

    /// In-memory store seeded with a few realistic groups, for SwiftUI
    /// previews, -demoData, and screenshots. Categories come from the Core ML
    /// categorizer, the same as typed expenses.
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let repository = ExpenseRepository(context: controller.container.viewContext, persistence: controller)
        let categorizer = ExpenseCategorizer()
        let calendar = Calendar.current

        // Created oldest first so the newest group is listed on top.
        let seeds: [(name: String, members: [String], expenses: [(String, Decimal, Int, Int)])] = [
            ("Ski Weekend", ["Dhyan", "Alex"], [
                ("Chalet in Chamonix", 600, 1, 9), ("Lift tickets", 180, 0, 8),
            ]),
            ("Flat 4B", ["Dhyan", "Sam", "Priya"], [
                ("Electricity bill", 120, 1, 6), ("Costco run", 210, 0, 4), ("Wifi", 45, 2, 3),
            ]),
            ("Lisbon Trip", ["Dhyan", "Maya", "Ravi"], [
                ("Airbnb in Alfama", 450, 0, 3), ("Dinner at Time Out Market", 96, 1, 2),
                ("Uber to the airport", 39, 2, 2), ("Fado show tickets", 75, 1, 1), ("Pastries and coffee", 18, 0, 0),
            ]),
        ]
        for seed in seeds {
            guard let groupID = try? repository.createGroup(name: seed.name, memberNames: seed.members, me: nil),
                  let group = try? repository.group(id: groupID)
            else { continue }
            let members = seed.members.compactMap { name in group.members.first { $0.name == name } }
            for (title, amount, payer, daysAgo) in seed.expenses {
                let expense = Expense(
                    id: UUID(), title: title, amount: amount, currencyCode: "USD",
                    category: categorizer.categorize(title: title), paidBy: members[payer],
                    splits: DebtSimplifier.equalSplits(of: amount, among: members),
                    date: calendar.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
                )
                try? repository.save(expense, in: groupID)
            }
        }
        return controller
    }()

    let container: NSPersistentCloudKitContainer
    private(set) var privateStore: NSPersistentStore?
    private(set) var sharedStore: NSPersistentStore?

    /// Sharing needs real CloudKit-backed stores, so it's off for in-memory stacks.
    var supportsSharing: Bool { sharedStore != nil }

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "SplitWiseClone", managedObjectModel: Self.model)

        guard let privateDescription = container.persistentStoreDescriptions.first,
              let privateURL = privateDescription.url
        else {
            fatalError("No persistent store description found.")
        }

        if inMemory {
            privateDescription.url = URL(fileURLWithPath: "/dev/null")
            privateDescription.cloudKitContainerOptions = nil
        } else if !AppFeatures.cloud {
            // Free build: a plain local store. History tracking stays on so
            // turning CloudKit on later can mirror everything already saved.
            privateDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            privateDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            privateDescription.cloudKitContainerOptions = nil
        } else {
            // History tracking + remote change notifications are required for
            // NSPersistentCloudKitContainer to sync correctly across devices.
            privateDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            privateDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            let privateOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: Self.cloudKitContainerID)
            privateOptions.databaseScope = .private
            privateDescription.cloudKitContainerOptions = privateOptions

            guard let sharedDescription = privateDescription.copy() as? NSPersistentStoreDescription else {
                fatalError("Couldn't copy the store description.")
            }
            sharedDescription.url = privateURL.deletingLastPathComponent().appendingPathComponent(Self.sharedStoreFileName)
            let sharedOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: Self.cloudKitContainerID)
            sharedOptions.databaseScope = .shared
            sharedDescription.cloudKitContainerOptions = sharedOptions
            container.persistentStoreDescriptions.append(sharedDescription)
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // Replace with real logging / user-facing error handling.
                fatalError("Unresolved Core Data + CloudKit error: \(error), \(error.userInfo)")
            }
        }

        let stores = container.persistentStoreCoordinator.persistentStores
        sharedStore = inMemory || !AppFeatures.cloud ? nil : stores.first { $0.url?.lastPathComponent == Self.sharedStoreFileName }
        privateStore = stores.first { $0 !== sharedStore }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    private static let sharedStoreFileName = "SplitWiseClone-shared.sqlite"

    /// Loaded once and shared: when several stacks exist in one process (tests,
    /// previews), each loading its own copy makes `CDGroup(context:)` resolve
    /// to the wrong model and saves fail as "incompatible model".
    private static let model: NSManagedObjectModel = {
        guard let url = Bundle.main.url(forResource: "SplitWiseClone", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url)
        else { fatalError("Couldn't load the Core Data model.") }
        return model
    }()

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

    // MARK: - Sharing

    var cloudKitContainer: CKContainer { CKContainer(identifier: Self.cloudKitContainerID) }

    func existingShare(for group: CDGroup) -> CKShare? {
        (try? container.fetchShares(matching: [group.objectID]))?[group.objectID]
    }

    /// Groups that live in the shared store belong to someone else.
    func isOwnedByOtherUser(_ group: CDGroup) -> Bool {
        sharedStore != nil && group.objectID.persistentStore === sharedStore
    }

    /// Returns the group's CKShare, creating one if needed. Sharing the group
    /// also shares everything hanging off it (members, expenses, payments).
    func share(_ group: CDGroup) async throws -> CKShare {
        if let share = existingShare(for: group) { return share }
        let (_, share, _) = try await container.share([group], to: nil)
        share[CKShare.SystemFieldKey.title] = group.name
        return share
    }

    /// Called when this user opens an invitation link from someone else.
    func acceptShare(_ metadata: CKShare.Metadata) {
        guard let sharedStore else { return }
        container.acceptShareInvitations(from: [metadata], into: sharedStore) { _, error in
            if let error { print("Failed to accept share: \(error)") }
        }
    }
}
