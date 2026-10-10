//
//  CoreDataMapping.swift
//  SplitWiseClone
//
//  Maps CD-prefixed managed objects to the plain domain structs, plus a
//  small fetch-by-id helper shared by the ViewModels.
//

import CoreData

extension NSManagedObjectContext {
    func fetchOne<T: NSManagedObject>(_ type: T.Type, id: UUID) throws -> T? {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try fetch(request).first
    }
}

extension CDMember {
    var domain: Member { Member(id: id ?? UUID(), name: name ?? "") }
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
            paidBy: payer.domain, splits: splits, date: date ?? .distantPast
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
