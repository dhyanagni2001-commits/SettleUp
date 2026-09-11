//
//  GroupDetailViewModel.swift
//  SplitWiseClone
//
//  Publishes a single group's expenses, per-member balances, and the
//  simplified settlement plan (via DebtSimplifier). Recomputes
//  reactively whenever the underlying expense list changes.
//

import Combine
import CoreData
import Foundation

@MainActor
final class GroupDetailViewModel: ObservableObject {
    @Published var group: ExpenseGroup
    @Published private(set) var balances: [Member: Decimal] = [:]
    @Published private(set) var settlements: [Settlement] = []
    @Published var errorMessage: String?

    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()

    init(group: ExpenseGroup, context: NSManagedObjectContext) {
        self.group = group
        self.context = context

        $group
            .map(\.expenses)
            .removeDuplicates()
            .sink { [weak self] expenses in
                self?.recompute(expenses: expenses)
            }
            .store(in: &cancellables)

        recompute(expenses: group.expenses)
    }

    private func recompute(expenses: [Expense]) {
        balances = DebtSimplifier.netBalances(for: expenses)
        settlements = DebtSimplifier.simplify(expenses: expenses)
    }

    func addExpense(_ expense: Expense) {
        // Look up the CDGroup and CDMember (paidBy) that already exist in the store.
        let groupRequest = CDGroup.fetchRequest()
        groupRequest.predicate = NSPredicate(format: "id == %@", group.id as CVarArg)

        let memberRequest = CDMember.fetchRequest()
        memberRequest.predicate = NSPredicate(format: "id == %@", expense.paidBy.id as CVarArg)

        do {
            guard let cdGroup = try context.fetch(groupRequest).first else {
                errorMessage = "Couldn't find this group in the store."
                return
            }
            guard let cdPaidBy = try context.fetch(memberRequest).first else {
                errorMessage = "Couldn't find the member who paid."
                return
            }

            let cdExpense = CDExpense(context: context)
            cdExpense.id = expense.id
            cdExpense.title = expense.title
            cdExpense.amount = expense.amount as NSDecimalNumber
            cdExpense.currencyCode = expense.currencyCode
            cdExpense.category = expense.category.rawValue
            cdExpense.date = expense.date
            cdExpense.group = cdGroup
            cdExpense.paidBy = cdPaidBy

            for split in expense.splits {
                let splitMemberRequest = CDMember.fetchRequest()
                splitMemberRequest.predicate = NSPredicate(format: "id == %@", split.member.id as CVarArg)
                guard let cdSplitMember = try context.fetch(splitMemberRequest).first else { continue }

                let cdSplit = CDExpenseSplit(context: context)
                cdSplit.id = split.id
                cdSplit.ownedAmount = split.owedAmount as NSDecimalNumber
                cdSplit.expense = cdExpense
                cdSplit.member = cdSplitMember
            }

            try context.save()
            group.expenses.append(expense)
        } catch {
            errorMessage = "Couldn't save expense: \(error.localizedDescription)"
        }
    }

    func markSettled(_ settlement: Settlement) {
        let fromRequest = CDMember.fetchRequest()
        fromRequest.predicate = NSPredicate(format: "id == %@", settlement.from.id as CVarArg)

        let toRequest = CDMember.fetchRequest()
        toRequest.predicate = NSPredicate(format: "id == %@", settlement.to.id as CVarArg)

        do {
            guard let cdFrom = try context.fetch(fromRequest).first else {
                errorMessage = "Couldn't find the paying member."
                return
            }
            guard let cdTo = try context.fetch(toRequest).first else {
                errorMessage = "Couldn't find the receiving member."
                return
            }

            let cdSettlement = CDSettlement(context: context)
            cdSettlement.id = UUID()
            cdSettlement.amount = settlement.amount as NSDecimalNumber
            cdSettlement.currencyCode = settlement.currencyCode
            cdSettlement.from = cdFrom
            cdSettlement.to = cdTo

            try context.save()

            // Remove from the displayed list immediately — it's a derived
            // (not stored) list, so this just reflects "already handled"
            // until the next full recompute.
            settlements.removeAll { $0.id == settlement.id }
        } catch {
            errorMessage = "Couldn't mark settled: \(error.localizedDescription)"
        }
    }
}
