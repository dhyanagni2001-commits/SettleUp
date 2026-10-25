//
//  ExpenseRepository.swift
//  SplitWiseClone
//
//  The one write path into Core Data. View models and App Intents both go
//  through here, so an expense dictated to Siri is validated, split, and
//  stored exactly like one entered in the form.
//

import CoreData
import Foundation

enum RepositoryError: LocalizedError {
    case groupNotFound
    case memberNotFound

    var errorDescription: String? {
        switch self {
        case .groupNotFound: "Couldn't find that group."
        case .memberNotFound: "Couldn't find that person in the group."
        }
    }
}

struct ExpenseRepository {
    let context: NSManagedObjectContext
    var persistence: PersistenceController?

    // MARK: Reads

    func groups() throws -> [ExpenseGroup] {
        let request = CDGroup.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDGroup.createdAt, ascending: false)]
        return try context.fetch(request).map(\.domain)
    }

    func group(id: UUID) throws -> ExpenseGroup? {
        try context.fetchOne(CDGroup.self, id: id)?.domain
    }

    // MARK: Groups

    @discardableResult
    func createGroup(name: String, memberNames: [String], me: (name: String, userID: String)?) throws -> UUID {
        let cdGroup = CDGroup(context: context)
        if let store = persistence?.privateStore { context.assign(cdGroup, to: store) }
        cdGroup.id = UUID()
        cdGroup.name = name
        cdGroup.createdAt = Date()

        var people = memberNames.map { (name: $0, userID: String?.none) }
        if let me { people.insert((me.name, me.userID), at: 0) }
        for person in people {
            let cdMember = context.insert(CDMember.self, alongside: cdGroup)
            cdMember.id = UUID()
            cdMember.name = person.name
            cdMember.userID = person.userID
            cdMember.group = cdGroup
        }
        try save()
        return cdGroup.id!
    }

    func addMember(named name: String, to groupID: UUID) throws {
        guard let cdGroup = try context.fetchOne(CDGroup.self, id: groupID) else { throw RepositoryError.groupNotFound }
        let cdMember = context.insert(CDMember.self, alongside: cdGroup)
        cdMember.id = UUID()
        cdMember.name = name
        cdMember.group = cdGroup
        try save()
    }

    func deleteGroup(id: UUID) throws {
        guard let cdGroup = try context.fetchOne(CDGroup.self, id: id) else { return }
        context.delete(cdGroup)
        try save()
    }

    // MARK: Expenses

    /// Adds `expense`, or replaces it if one with the same id already exists.
    func save(_ expense: Expense, in groupID: UUID) throws {
        guard let cdGroup = try context.fetchOne(CDGroup.self, id: groupID) else { throw RepositoryError.groupNotFound }
        try ExpenseValidator.validate(expense, in: cdGroup.domain)
        guard let cdPaidBy = try context.fetchOne(CDMember.self, id: expense.paidBy.id) else { throw RepositoryError.memberNotFound }

        let cdExpense: CDExpense
        if let existing = try context.fetchOne(CDExpense.self, id: expense.id) {
            cdExpense = existing
            (existing.splits as? Set<CDExpenseSplit>)?.forEach(context.delete)
        } else {
            cdExpense = context.insert(CDExpense.self, alongside: cdGroup)
            cdExpense.id = expense.id
        }
        cdExpense.title = expense.title.trimmingCharacters(in: .whitespacesAndNewlines)
        cdExpense.amount = expense.amount as NSDecimalNumber
        cdExpense.currencyCode = expense.currencyCode.uppercased()
        cdExpense.category = expense.category.rawValue
        cdExpense.date = expense.date
        cdExpense.group = cdGroup
        cdExpense.paidBy = cdPaidBy

        for split in expense.splits {
            guard let cdSplitMember = try context.fetchOne(CDMember.self, id: split.member.id) else { throw RepositoryError.memberNotFound }
            let cdSplit = context.insert(CDExpenseSplit.self, alongside: cdGroup)
            cdSplit.id = split.id
            cdSplit.ownedAmount = split.owedAmount as NSDecimalNumber
            cdSplit.expense = cdExpense
            cdSplit.member = cdSplitMember
        }
        try save()
    }

    func deleteExpense(id: UUID) throws {
        guard let cdExpense = try context.fetchOne(CDExpense.self, id: id) else { return }
        context.delete(cdExpense)
        try save()
    }

    // MARK: Payments

    func recordPayment(_ settlement: Settlement, in groupID: UUID) throws {
        guard let cdGroup = try context.fetchOne(CDGroup.self, id: groupID) else { throw RepositoryError.groupNotFound }
        guard let cdFrom = try context.fetchOne(CDMember.self, id: settlement.from.id),
              let cdTo = try context.fetchOne(CDMember.self, id: settlement.to.id)
        else { throw RepositoryError.memberNotFound }

        let cdSettlement = context.insert(CDSettlement.self, alongside: cdGroup)
        cdSettlement.id = UUID()
        cdSettlement.amount = settlement.amount as NSDecimalNumber
        cdSettlement.currencyCode = settlement.currencyCode
        cdSettlement.date = Date()
        cdSettlement.from = cdFrom
        cdSettlement.to = cdTo
        cdSettlement.group = cdGroup
        try save()
    }

    // MARK: Account linking

    /// Marks `memberID` as the signed-in person within its group.
    func claimMember(_ memberID: UUID, in groupID: UUID, userID: String) throws {
        guard let cdGroup = try context.fetchOne(CDGroup.self, id: groupID) else { throw RepositoryError.groupNotFound }
        for member in cdGroup.members as? Set<CDMember> ?? [] {
            if member.id == memberID { member.userID = userID } else if member.userID == userID { member.userID = nil }
        }
        try save()
    }

    /// A guest who signs in keeps everything: their members move to the new id.
    func relinkUser(from oldID: String, to newID: String) throws {
        let request = CDMember.fetchRequest()
        request.predicate = NSPredicate(format: "userID == %@", oldID)
        for member in try context.fetch(request) { member.userID = newID }
        try save()
    }

    /// Account deletion: remove this person's own groups, and unlink them from
    /// groups other people shared with them.
    func deleteAllData(for userID: String?) throws {
        for cdGroup in try context.fetch(CDGroup.fetchRequest()) {
            if let persistence, persistence.isOwnedByOtherUser(cdGroup) {
                for member in cdGroup.members as? Set<CDMember> ?? [] where member.userID == userID { member.userID = nil }
            } else {
                context.delete(cdGroup)
            }
        }
        try save()
    }

    private func save() throws {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
