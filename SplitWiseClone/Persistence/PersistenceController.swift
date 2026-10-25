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

    /// The stack this launch should use. Tests get a clean in-memory store;
    /// -demoData launches with the seeded preview store. App Intents read
    /// this too, so Siri writes land in the same store as the UI.
    static let current: PersistenceController = {
        if isTesting { return PersistenceController(inMemory: true) }
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-demoData") { return .preview }
        return .shared
    }()

    /// In-memory store used by SwiftUI previews and unit tests.
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let group = CDGroup(context: context)
        group.id = UUID(); group.name = "Lisbon Trip"; group.createdAt = Date()
        let members = ["Dhyan", "Alex", "Priya"].map { name in
            let member = CDMember(context: context)
            member.id = UUID(); member.name = name; member.group = group
            return member
        }
        for (title, amount, payer) in [("Airbnb", 450, 0), ("Dinner at Time Out", 96, 1), ("Uber to airport", 39, 2)] {
            let expense = CDExpense(context: context)
            expense.id = UUID(); expense.title = title; expense.amount = NSDecimalNumber(value: amount)
            expense.currencyCode = "USD"; expense.date = Date(); expense.group = group; expense.paidBy = members[payer]
            expense.category = ExpenseCategorizer().categorize(title: title).rawValue
            for split in DebtSimplifier.equalSplits(of: Decimal(amount), among: members.map(\.domain)) {
                let cdSplit = CDExpenseSplit(context: context)
                cdSplit.id = split.id; cdSplit.ownedAmount = split.owedAmount as NSDecimalNumber
                cdSplit.expense = expense; cdSplit.member = members.first { $0.id == split.member.id }
            }
        }
        try? context.save()
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
        sharedStore = inMemory ? nil : stores.first { $0.url?.lastPathComponent == Self.sharedStoreFileName }
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
