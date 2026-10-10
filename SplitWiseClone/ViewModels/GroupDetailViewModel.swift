//
//  GroupDetailViewModel.swift
//  SplitWiseClone
//
//  Publishes a single group's expenses, per-member balances, and the
//  simplified settlement plan (via DebtSimplifier). Recorded payments are
//  folded into the ledger, so settling up actually zeroes balances.
//

import Combine
import CoreData
import Foundation

@MainActor
final class GroupDetailViewModel: ObservableObject {
    @Published private(set) var group: ExpenseGroup {
        didSet { recompute() }
    }
    @Published private(set) var balances: [MemberBalance] = []
    @Published private(set) var settlements: [Settlement] = []
    @Published var errorMessage: String?

    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()

    init(groupID: UUID, context: NSManagedObjectContext) {
        self.context = context
        self.group = (try? context.fetchOne(CDGroup.self, id: groupID))?.domain
            ?? ExpenseGroup(id: groupID, name: "", members: [], expenses: [])
        recompute()

        NotificationCenter.default
            .publisher(for: .NSPersistentStoreRemoteChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)
    }

    private func reload() {
        if let cdGroup = try? context.fetchOne(CDGroup.self, id: group.id) {
            group = cdGroup.domain
        }
    }

    private func recompute() {
        let ledger = group.expenses + group.payments.map(DebtSimplifier.ledgerEntry)
        let net = DebtSimplifier.netBalances(for: ledger)
        balances = group.members
            .map { MemberBalance(member: $0, amount: net[$0] ?? 0) }
            .sorted { $0.amount > $1.amount }
        settlements = DebtSimplifier.simplify(expenses: ledger)
            .sorted { $0.amount > $1.amount }
    }

    func addExpense(_ expense: Expense) {
        do {
            guard let cdGroup = try context.fetchOne(CDGroup.self, id: group.id),
                  let cdPaidBy = try context.fetchOne(CDMember.self, id: expense.paidBy.id)
            else {
                errorMessage = "Couldn't find this group or payer in the store."
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
                guard let cdSplitMember = try context.fetchOne(CDMember.self, id: split.member.id) else { continue }
                let cdSplit = CDExpenseSplit(context: context)
                cdSplit.id = split.id
                cdSplit.ownedAmount = split.owedAmount as NSDecimalNumber
                cdSplit.expense = cdExpense
                cdSplit.member = cdSplitMember
            }
            try save()
        } catch {
            errorMessage = "Couldn't save expense: \(error.localizedDescription)"
        }
    }

    func deleteExpense(_ expense: Expense) {
        do {
            guard let cdExpense = try context.fetchOne(CDExpense.self, id: expense.id) else { return }
            context.delete(cdExpense)
            try save()
        } catch {
            errorMessage = "Couldn't delete expense: \(error.localizedDescription)"
        }
    }

    func markSettled(_ settlement: Settlement) {
        do {
            guard let cdGroup = try context.fetchOne(CDGroup.self, id: group.id),
                  let cdFrom = try context.fetchOne(CDMember.self, id: settlement.from.id),
                  let cdTo = try context.fetchOne(CDMember.self, id: settlement.to.id)
            else {
                errorMessage = "Couldn't find the members for this payment."
                return
            }

            let cdSettlement = CDSettlement(context: context)
            cdSettlement.id = UUID()
            cdSettlement.amount = settlement.amount as NSDecimalNumber
            cdSettlement.currencyCode = settlement.currencyCode
            cdSettlement.date = Date()
            cdSettlement.from = cdFrom
            cdSettlement.to = cdTo
            cdSettlement.group = cdGroup
            try save()
        } catch {
            errorMessage = "Couldn't mark settled: \(error.localizedDescription)"
        }
    }

    private func save() throws {
        do {
            try context.save()
            reload()
        } catch {
            context.rollback()
            throw error
        }
    }
}
