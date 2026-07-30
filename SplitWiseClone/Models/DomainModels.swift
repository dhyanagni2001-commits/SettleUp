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
}

struct Member: Identifiable, Hashable {
    let id: UUID
    var name: String
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
}

struct ExpenseSplit: Identifiable, Hashable {
    let id: UUID
    var member: Member
    var owedAmount: Decimal
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
}
