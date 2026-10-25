//
//  ExpenseValidator.swift
//  SplitWiseClone
//
//  The single set of rules every expense must pass before it's saved,
//  whether it was typed into the form or dictated to Siri.
//

import Foundation

enum ExpenseValidationError: LocalizedError, Equatable {
    case missingTitle
    case nonPositiveAmount
    case tooManyDecimals
    case unknownCurrency(String)
    case noParticipants
    case payerNotInGroup
    case participantNotInGroup(String)
    case negativeShare(String)
    case splitsDontAddUp(total: Decimal, splits: Decimal)

    var errorDescription: String? {
        switch self {
        case .missingTitle: "Add a description for the expense."
        case .nonPositiveAmount: "The amount must be more than zero."
        case .tooManyDecimals: "Amounts can't have more than two decimal places."
        case .unknownCurrency(let code): "\(code) isn't a currency SettleUp recognizes."
        case .noParticipants: "Pick at least one person to split with."
        case .payerNotInGroup: "The person who paid isn't in this group."
        case .participantNotInGroup(let name): "\(name) isn't in this group."
        case .negativeShare(let name): "\(name)'s share can't be negative."
        case let .splitsDontAddUp(total, splits):
            "The shares add up to \(splits.formatted()) but the total is \(total.formatted())."
        }
    }
}

enum ExpenseValidator {
    static func validate(_ expense: Expense, in group: ExpenseGroup) throws {
        if expense.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw ExpenseValidationError.missingTitle }
        if expense.amount <= 0 { throw ExpenseValidationError.nonPositiveAmount }
        if !hasAtMostTwoDecimals(expense.amount) { throw ExpenseValidationError.tooManyDecimals }
        if !isKnownCurrency(expense.currencyCode) { throw ExpenseValidationError.unknownCurrency(expense.currencyCode) }

        let memberIDs = Set(group.members.map(\.id))
        if !memberIDs.contains(expense.paidBy.id) { throw ExpenseValidationError.payerNotInGroup }
        if expense.splits.isEmpty { throw ExpenseValidationError.noParticipants }
        for split in expense.splits {
            if !memberIDs.contains(split.member.id) { throw ExpenseValidationError.participantNotInGroup(split.member.name) }
            if split.owedAmount < 0 { throw ExpenseValidationError.negativeShare(split.member.name) }
            if !hasAtMostTwoDecimals(split.owedAmount) { throw ExpenseValidationError.tooManyDecimals }
        }

        // Exact to the cent: leftover cents must be assigned to someone.
        let sum = expense.splits.reduce(Decimal(0)) { $0 + $1.owedAmount }
        if sum != expense.amount { throw ExpenseValidationError.splitsDontAddUp(total: expense.amount, splits: sum) }
    }

    static func isKnownCurrency(_ code: String) -> Bool {
        Locale.commonISOCurrencyCodes.contains(code.uppercased())
    }

    static func hasAtMostTwoDecimals(_ value: Decimal) -> Bool {
        var cents = value * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &cents, 0, .plain)
        return rounded == cents
    }
}
