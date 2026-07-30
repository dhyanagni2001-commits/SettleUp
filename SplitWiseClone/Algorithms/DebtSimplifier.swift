//
//  DebtSimplifier.swift
//  SplitWiseClone
//
//  Reduces a group's tangle of individual expense splits down to the
//  minimum number of payments needed to zero out every balance —
//  a min-transaction graph reduction ("optimal account balancing").
//
//  Algorithm:
//   1. Net every member's balance: sum of what they paid minus sum of
//      what they owe across all expenses, per currency.
//   2. Greedily match the member with the largest credit against the
//      member with the largest debit, settle the smaller of the two
//      amounts, and repeat until all balances are ~0.
//
//  This greedy approach is not guaranteed to produce the mathematically
//  minimal transaction count in every case (that's an NP-hard set
//  partitioning problem in general), but it's a well-known, fast,
//  good-in-practice approximation and is what most expense-splitting
//  apps ship. Documented here so it reads as a deliberate tradeoff,
//  not an oversight.
//

import Foundation

enum DebtSimplifier {

    /// Rounding precision for currency math. Using cents (2 decimal places)
    /// avoids floating-point drift; Decimal is exact but we still need to
    /// decide how to round remainders when a group's balances don't sum
    /// to exactly zero (e.g. due to prior rounding elsewhere).
    static let scale = 2

    /// Computes the minimal-ish set of settlements needed to zero out
    /// every member's balance, grouped by currency (cross-currency debts
    /// are NOT netted against each other — that would require a live FX
    /// rate and is out of scope here).
    static func simplify(expenses: [Expense]) -> [Settlement] {
        let expensesByCurrency = Dictionary(grouping: expenses, by: \.currencyCode)
        var allSettlements: [Settlement] = []

        for (currencyCode, currencyExpenses) in expensesByCurrency {
            let balances = netBalances(for: currencyExpenses)
            allSettlements += settlements(from: balances, currencyCode: currencyCode)
        }

        return allSettlements
    }

    /// Positive balance = is owed money overall. Negative = owes money overall.
    static func netBalances(for expenses: [Expense]) -> [Member: Decimal] {
        var balances: [Member: Decimal] = [:]

        for expense in expenses {
            balances[expense.paidBy, default: 0] += expense.amount
            for split in expense.splits {
                balances[split.member, default: 0] -= split.owedAmount
            }
        }

        return balances.mapValues { round($0) }
    }

    /// Greedy max-creditor/max-debtor matching.
    static func settlements(from balances: [Member: Decimal], currencyCode: String) -> [Settlement] {
        // Split into creditors (owed money, balance > 0) and debtors (owe money, balance < 0).
        var creditors = balances.filter { $0.value > 0 }
        var debtors = balances.filter { $0.value < 0 }

        var results: [Settlement] = []

        while !creditors.isEmpty && !debtors.isEmpty {
            guard let topCreditor = creditors.max(by: { $0.value < $1.value }),
                  let topDebtor = debtors.min(by: { $0.value < $1.value }) // most negative
            else { break }

            let amountOwed = -topDebtor.value // positive number
            let settleAmount = min(topCreditor.value, amountOwed)

            if settleAmount > 0 {
                results.append(
                    Settlement(
                        id: UUID(),
                        from: topDebtor.key,
                        to: topCreditor.key,
                        amount: round(settleAmount),
                        currencyCode: currencyCode
                    )
                )
            }

            let newCreditorBalance = round(topCreditor.value - settleAmount)
            let newDebtorBalance = round(topDebtor.value + settleAmount)

            if newCreditorBalance == 0 {
                creditors.removeValue(forKey: topCreditor.key)
            } else {
                creditors[topCreditor.key] = newCreditorBalance
            }

            if newDebtorBalance == 0 {
                debtors.removeValue(forKey: topDebtor.key)
            } else {
                debtors[topDebtor.key] = newDebtorBalance
            }
        }

        return results
    }

    private static func round(_ value: Decimal) -> Decimal {
        var result = Decimal()
        var mutableValue = value
        NSDecimalRound(&result, &mutableValue, scale, .plain)
        return result
    }
}
