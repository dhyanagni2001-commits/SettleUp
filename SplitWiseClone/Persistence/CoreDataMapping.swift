//
//  CoreDataMapping.swift
//  SplitWiseClone
//
//  Maps CD-prefixed managed objects to the plain domain structs, plus small
//  fetch/insert helpers shared by the repository.
//

import CoreData

extension NSManagedObjectContext {
    func fetchOne<T: NSManagedObject>(_ type: T.Type, id: UUID) throws -> T? {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try fetch(request).first
    }

    /// Inserts a new object into the same store as `anchor`. Core Data can't
    /// relate objects across stores, so anything added to a shared group has
    /// to live in the shared store too.
    func insert<T: NSManagedObject>(_ type: T.Type, alongside anchor: NSManagedObject) -> T {
        let object = T(context: self)
        if let store = anchor.objectID.persistentStore { assign(object, to: store) }
        return object
    }
}

extension CDMember {
    var domain: Member { Member(id: id ?? UUID(), name: name ?? "", userID: userID) }
}

extension CDExpense {
    var domain: Expense? {
        guard let id, let payer = paidBy else { return nil }
        let splits = (splits as? Set<CDExpenseSplit> ?? []).compactMap { split -> ExpenseSplit? in
            guard let member = split.member else { return nil }
            return ExpenseSplit(id: split.id ?? UUID(), member: member.domain, owedAmount: split.ownedAmount?.decimalValue ?? 0)
        }
        return Expense(
            id: id, title: title ?? "", amount: amount?.decimalValue ?? 0,
            currencyCode: currencyCode ?? "USD",
            category: ExpenseCategory(rawValue: category ?? "") ?? .other,
            paidBy: payer.domain, splits: splits.sorted { $0.member.name < $1.member.name },
            date: date ?? .distantPast
        )
    }
}

extension CDSettlement {
    var domain: Settlement? {
        guard let id, let from, let to else { return nil }
        return Settlement(id: id, from: from.domain, to: to.domain, amount: amount?.decimalValue ?? 0,
                          currencyCode: currencyCode ?? "USD", date: date ?? .distantPast)
    }
}

extension CDGroup {
    var domain: ExpenseGroup {
        ExpenseGroup(
            id: id ?? UUID(),
            name: name ?? "",
            members: (members as? Set<CDMember> ?? []).map(\.domain).sorted { $0.name < $1.name },
            expenses: (expenses as? Set<CDExpense> ?? []).compactMap(\.domain).sorted { $0.date > $1.date },
            payments: (settlements as? Set<CDSettlement> ?? []).compactMap(\.domain).sorted { $0.date > $1.date }
        )
    }
}
