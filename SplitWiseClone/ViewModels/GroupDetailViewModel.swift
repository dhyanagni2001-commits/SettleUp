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

    let userID: String?
    var me: Member? { group.me(userID) }

    private let repository: ExpenseRepository
    private var cancellables = Set<AnyCancellable>()

    init(groupID: UUID, repository: ExpenseRepository, userID: String?) {
        self.repository = repository
        self.userID = userID
        self.group = (try? repository.group(id: groupID))
            ?? ExpenseGroup(id: groupID, name: "", members: [], expenses: [])
        recompute()

        Publishers.Merge(
            NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange),
            NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: repository.context)
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in self?.reload() }
        .store(in: &cancellables)
    }

    convenience init(groupID: UUID, context: NSManagedObjectContext) {
        self.init(groupID: groupID, repository: ExpenseRepository(context: context), userID: nil)
    }

    private func reload() {
        if let fresh = try? repository.group(id: group.id), fresh != group {
            group = fresh
        }
    }

    private func recompute() {
        balances = group.balances
        settlements = group.settlementPlan
    }

    func saveExpense(_ expense: Expense) {
        perform("save expense") { try repository.save(expense, in: group.id) }
    }

    func deleteExpense(_ expense: Expense) {
        perform("delete expense") { try repository.deleteExpense(id: expense.id) }
    }

    func markSettled(_ settlement: Settlement) {
        perform("record payment") { try repository.recordPayment(settlement, in: group.id) }
    }

    func claim(_ member: Member) {
        guard let userID else { return }
        perform("update group") { try repository.claimMember(member.id, in: group.id, userID: userID) }
    }

    func addMember(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        perform("add member") { try repository.addMember(named: trimmed, to: group.id) }
    }

    private func perform(_ action: String, _ work: () throws -> Void) {
        do {
            try work()
            reload()
        } catch {
            errorMessage = "Couldn't \(action): \(error.localizedDescription)"
        }
    }
}
