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
            for member in members {
                let split = CDExpenseSplit(context: context)
                split.id = UUID(); split.ownedAmount = NSDecimalNumber(value: Double(amount) / 3)
                split.expense = expense; split.member = member
            }
        }
        try? context.save()
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
