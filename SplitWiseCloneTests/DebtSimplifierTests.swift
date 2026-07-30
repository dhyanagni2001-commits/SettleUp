//
//  DebtSimplifierTests.swift
//  SplitWiseCloneTests
//
//  Unit tests for the debt-simplification (min-transaction) algorithm.
//  Covers: basic 3-person reduction, exact rounding to cents, an
//  already-settled group, and multi-currency isolation.
//

import XCTest
@testable import SplitWiseClone

final class DebtSimplifierTests: XCTestCase {

    private func member(_ name: String) -> Member {
        Member(id: UUID(), name: name)
    }

    // MARK: - Basic reduction

    func testThreePersonDinner_ReducesToTwoPayments() {
        // Alice pays $90 for dinner, split equally 3 ways ($30 each).
        let alice = member("Alice")
        let bob = member("Bob")
        let carol = member("Carol")

        let dinner = Expense(
            id: UUID(),
            title: "Dinner",
            amount: 90,
            currencyCode: "USD",
            category: .food,
            paidBy: alice,
            splits: [
                ExpenseSplit(id: UUID(), member: alice, owedAmount: 30),
                ExpenseSplit(id: UUID(), member: bob, owedAmount: 30),
                ExpenseSplit(id: UUID(), member: carol, owedAmount: 30),
            ],
            date: Date()
        )

        let settlements = DebtSimplifier.simplify(expenses: [dinner])

        // Bob and Carol each owe Alice $30 — 2 payments, not 3.
        XCTAssertEqual(settlements.count, 2)
        XCTAssertTrue(settlements.allSatisfy { $0.to == alice })
        XCTAssertEqual(settlements.reduce(0) { $0 + $1.amount }, 60)
    }

    // MARK: - Rounding

    func testUnevenSplit_RoundsToNearestCent() {
        // $100 split 3 ways = $33.333... each. Payer's own share rounds too.
        let alice = member("Alice")
        let bob = member("Bob")
        let carol = member("Carol")

        let share = (Decimal(100) as NSDecimalNumber)
            .dividing(by: NSDecimalNumber(value: 3)).decimalValue

        let expense = Expense(
            id: UUID(), title: "Groceries", amount: 100, currencyCode: "USD",
            category: .groceries, paidBy: alice,
            splits: [
                ExpenseSplit(id: UUID(), member: alice, owedAmount: share),
                ExpenseSplit(id: UUID(), member: bob, owedAmount: share),
                ExpenseSplit(id: UUID(), member: carol, owedAmount: share),
            ],
            date: Date()
        )

        let settlements = DebtSimplifier.simplify(expenses: [expense])

        // No settlement amount should carry more than 2 decimal places.
        for settlement in settlements {
            let scaled = (settlement.amount as NSDecimalNumber)
                .multiplying(byPowerOf10: 2)
            var rounded = Decimal()
            var mutableScaled = scaled.decimalValue
            NSDecimalRound(&rounded, &mutableScaled, 0, .plain)
            XCTAssertEqual(scaled.decimalValue, rounded, "Settlement amount has sub-cent precision: \(settlement.amount)")
        }
    }

    // MARK: - Already settled

    func testBalancedGroup_ProducesNoSettlements() {
        let alice = member("Alice")
        let bob = member("Bob")

        let expense = Expense(
            id: UUID(), title: "Split evenly", amount: 20, currencyCode: "USD",
            category: .other, paidBy: alice,
            splits: [
                ExpenseSplit(id: UUID(), member: alice, owedAmount: 10),
                ExpenseSplit(id: UUID(), member: bob, owedAmount: 10),
            ],
            date: Date()
        )

        // Bob immediately covers an equal expense the other way, netting to zero.
        let reverseExpense = Expense(
            id: UUID(), title: "Return favor", amount: 20, currencyCode: "USD",
            category: .other, paidBy: bob,
            splits: [
                ExpenseSplit(id: UUID(), member: alice, owedAmount: 10),
                ExpenseSplit(id: UUID(), member: bob, owedAmount: 10),
            ],
            date: Date()
        )

        let settlements = DebtSimplifier.simplify(expenses: [expense, reverseExpense])
        XCTAssertTrue(settlements.isEmpty)
    }

    // MARK: - Multi-currency isolation

    func testMultiCurrencyExpenses_AreNeverNettedAcrossCurrencies() {
        let alice = member("Alice")
        let bob = member("Bob")

        let usdExpense = Expense(
            id: UUID(), title: "US dinner", amount: 40, currencyCode: "USD",
            category: .food, paidBy: alice,
            splits: [
                ExpenseSplit(id: UUID(), member: alice, owedAmount: 20),
                ExpenseSplit(id: UUID(), member: bob, owedAmount: 20),
            ],
            date: Date()
        )

        let eurExpense = Expense(
            id: UUID(), title: "EU dinner", amount: 40, currencyCode: "EUR",
            category: .food, paidBy: bob,
            splits: [
                ExpenseSplit(id: UUID(), member: alice, owedAmount: 20),
                ExpenseSplit(id: UUID(), member: bob, owedAmount: 20),
            ],
            date: Date()
        )

        let settlements = DebtSimplifier.simplify(expenses: [usdExpense, eurExpense])

        // Bob owes Alice $20 USD; Alice owes Bob €20 EUR. These must NOT
        // cancel out — they're different currencies — so we expect two
        // separate settlements, one per currency.
        XCTAssertEqual(settlements.count, 2)
        XCTAssertTrue(settlements.contains { $0.currencyCode == "USD" && $0.from == bob && $0.to == alice })
        XCTAssertTrue(settlements.contains { $0.currencyCode == "EUR" && $0.from == alice && $0.to == bob })
    }

    // MARK: - Larger group

    func testFivePersonGroup_NeverExceedsNMinusOnePayments() {
        let members = (1...5).map { member("Member\($0)") }
        let payer = members[0]

        // One person fronts $500, split unevenly across the group.
        let amounts: [Decimal] = [50, 275, 25, 100, 50]
        let splits = zip(members, amounts).map {
            ExpenseSplit(id: UUID(), member: $0.0, owedAmount: $0.1)
        }

        let expense = Expense(
            id: UUID(), title: "Group trip", amount: 500, currencyCode: "USD",
            category: .lodging, paidBy: payer, splits: splits, date: Date()
        )

        let settlements = DebtSimplifier.simplify(expenses: [expense])

        // For n members, min-transaction reduction never needs more than n-1 payments.
        XCTAssertLessThanOrEqual(settlements.count, members.count - 1)
    }
}
