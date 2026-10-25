//
//  DomainModels.swift
//  SplitWiseClone
//
//  Plain Swift value types used throughout the ViewModel/View layer.
//  Keeping these decoupled from NSManagedObject subclasses means the
//  algorithm and view code can be unit-tested without spinning up Core Data.
//

import Foundation

struct ExpenseGroup: Identifiable, Hashable {
    let id: UUID
    var name: String
    var members: [Member]
    var expenses: [Expense]
    /// Payments already recorded via "Settle up"; they offset balances.
    var payments: [Settlement] = []

    var totalSpent: Decimal { expenses.reduce(0) { $0 + $1.amount } }

    /// The currency most of this group's expenses use; what totals are shown in.
    var primaryCurrency: String {
        let counts = Dictionary(grouping: expenses, by: \.currencyCode).mapValues(\.count)
        return counts.max { $0.value < $1.value }?.key ?? "USD"
    }

    /// Expenses plus recorded payments, so settled amounts don't reappear.
    var ledger: [Expense] { expenses + payments.map { DebtSimplifier.ledgerEntry(for: $0) } }

    var balances: [MemberBalance] {
        let net = DebtSimplifier.netBalances(for: ledger)
        return members
            .map { MemberBalance(member: $0, amount: net[$0] ?? 0) }
            .sorted { $0.amount > $1.amount }
    }

    var settlementPlan: [Settlement] {
        DebtSimplifier.simplify(expenses: ledger).sorted { $0.amount > $1.amount }
    }

    /// The member the signed-in person has said is them, if any.
    func me(_ userID: String?) -> Member? {
        guard let userID else { return nil }
        return members.first { $0.userID == userID }
    }

    func balance(of member: Member) -> Decimal {
        balances.first { $0.member.id == member.id }?.amount ?? 0
    }
}

struct Member: Identifiable, Hashable {
    let id: UUID
    var name: String
    /// Account identifier of the person this member represents, once they've
    /// claimed it. Syncs with the group, so each collaborator can find "me".
    var userID: String? = nil
}

struct Expense: Identifiable, Hashable {
    let id: UUID
    var title: String
    var amount: Decimal
    var currencyCode: String
    var category: ExpenseCategory
    var paidBy: Member
    /// How much of `amount` each member owes. Should sum to `amount`.
    var splits: [ExpenseSplit]
    var date: Date

    /// Equal if every share is within a cent of every other share.
    var splitType: SplitType {
        let shares = splits.map(\.owedAmount)
        guard let low = shares.min(), let high = shares.max() else { return .equal }
        return high - low <= Decimal(string: "0.01")! ? .equal : .custom
    }
}

struct ExpenseSplit: Identifiable, Hashable {
    let id: UUID
    var member: Member
    var owedAmount: Decimal
}

nonisolated enum SplitType: String, CaseIterable, Codable, Sendable {
    case equal, custom
}

enum ExpenseCategory: String, CaseIterable, Codable {
    case food = "Food & Drink"
    case transport = "Transport"
    case lodging = "Lodging"
    case entertainment = "Entertainment"
    case utilities = "Utilities"
    case groceries = "Groceries"
    case other = "Other"
}

/// A single payment produced by `DebtSimplifier` that closes out one or more
/// underlying debts between two members.
struct Settlement: Identifiable, Hashable {
    let id: UUID
    var from: Member
    var to: Member
    var amount: Decimal
    var currencyCode: String
    var date: Date = Date()

    /// Stable identity for animations (simplifier output gets fresh UUIDs on every recompute).
    var pairKey: String { "\(from.id)-\(to.id)-\(currencyCode)" }
}

/// One member's net position within a group. Positive = is owed money.
struct MemberBalance: Identifiable, Equatable {
    let member: Member
    let amount: Decimal
    var id: UUID { member.id }
}

/// A partly-filled expense handed from Siri to the app for review.
struct ExpenseDraft: Identifiable, Equatable {
    let id = UUID()
    var groupID: UUID
    var title: String = ""
    var amount: Decimal?
    var currencyCode: String = "USD"
    var paidByID: UUID?
    var participantIDs: [UUID] = []
    var splitType: SplitType = .equal
    var date: Date = .now
}
