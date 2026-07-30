//
//  GroupDetailViewModel.swift
//  SplitWiseClone
//
//  Publishes a single group's expenses, per-member balances, and the
//  simplified settlement plan (via DebtSimplifier). Recomputes
//  reactively whenever the underlying expense list changes.
//

import Combine
import Foundation

@MainActor
final class GroupDetailViewModel: ObservableObject {
    @Published var group: ExpenseGroup
    @Published private(set) var balances: [Member: Decimal] = [:]
    @Published private(set) var settlements: [Settlement] = []

    private var cancellables = Set<AnyCancellable>()

    init(group: ExpenseGroup) {
        self.group = group

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
        group.expenses.append(expense)
        // TODO: persist via Core Data (create CDExpense + CDExpenseSplit
        // rows) and call PersistenceController.shared.save().
    }

    func markSettled(_ settlement: Settlement) {
        // TODO: persist a CDSettlement record with settledAt = Date().
    }
}
