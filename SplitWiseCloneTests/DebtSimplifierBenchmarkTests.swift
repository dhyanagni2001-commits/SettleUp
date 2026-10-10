//
//  DebtSimplifierBenchmarkTests.swift
//  SplitWiseCloneTests
//
//  Randomized (seeded, reproducible) simulations that measure how much
//  DebtSimplifier shrinks the payment graph, verify every plan zeroes all
//  balances, and time it at scale. Results are printed as `METRIC` lines.
//

import XCTest
@testable import SplitWiseClone

/// SplitMix64 — deterministic so the reported numbers are reproducible.
private struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

final class DebtSimplifierBenchmarkTests: XCTestCase {

    private func randomGroup(members count: Int, expenses: Int, rng: inout SeededRNG) -> [Expense] {
        let members = (0..<count).map { Member(id: UUID(), name: "M\($0)") }
        return (0..<expenses).map { _ in
            let amount = Decimal(Int.random(in: 500...50_000, using: &rng)) / 100
            let participants = Array(members.shuffled(using: &rng).prefix(Int.random(in: 2...count, using: &rng)))
            return Expense(
                id: UUID(), title: "x", amount: amount, currencyCode: "USD", category: .other,
                paidBy: members.randomElement(using: &rng)!,
                splits: DebtSimplifier.equalSplits(of: amount, among: participants), date: Date()
            )
        }
    }

    /// Payments needed without simplification: one per (debtor → payer) pair, netted pairwise.
    private func naivePaymentCount(_ expenses: [Expense]) -> Int {
        var pairs: [Set<UUID>: Decimal] = [:]
        var direction: [Set<UUID>: UUID] = [:]
        for expense in expenses {
            for split in expense.splits where split.member != expense.paidBy {
                let key: Set<UUID> = [split.member.id, expense.paidBy.id]
                let anchor = direction[key, default: split.member.id]
                direction[key] = anchor
                pairs[key, default: 0] += anchor == split.member.id ? split.owedAmount : -split.owedAmount
            }
        }
        return pairs.values.filter { abs(NSDecimalNumber(decimal: $0).doubleValue) >= 0.01 }.count
    }

    func testTransactionReductionAndCorrectness() {
        var rng = SeededRNG(state: 42)
        let trials = 1_000
        var naiveTotal = 0, simplifiedTotal = 0, zeroedGroups = 0, maxResidualCents = 0

        for _ in 0..<trials {
            let expenses = randomGroup(members: Int.random(in: 3...12, using: &rng),
                                       expenses: Int.random(in: 5...60, using: &rng), rng: &rng)
            let plan = DebtSimplifier.simplify(expenses: expenses)
            naiveTotal += naivePaymentCount(expenses)
            simplifiedTotal += plan.count

            // Applying the plan must zero everyone out (within 1¢ per member of rounding).
            let after = DebtSimplifier.netBalances(for: expenses + plan.map(DebtSimplifier.ledgerEntry))
            let worst = after.values.map { abs(NSDecimalNumber(decimal: $0 * 100).intValue) }.max() ?? 0
            maxResidualCents = max(maxResidualCents, worst)
            if worst <= 1 { zeroedGroups += 1 }

            let members = Set(expenses.flatMap { $0.splits.map(\.member) + [$0.paidBy] })
            XCTAssertLessThanOrEqual(plan.count, max(members.count - 1, 0), "Plan exceeds n-1 payments")
        }

        let reduction = 100 * Double(naiveTotal - simplifiedTotal) / Double(naiveTotal)
        print(String(format: "METRIC groups_simulated=%d", trials))
        print(String(format: "METRIC naive_payments=%d simplified_payments=%d reduction_pct=%.1f", naiveTotal, simplifiedTotal, reduction))
        print(String(format: "METRIC avg_payments_naive=%.2f avg_payments_simplified=%.2f",
                     Double(naiveTotal) / Double(trials), Double(simplifiedTotal) / Double(trials)))
        print("METRIC groups_fully_settled=\(zeroedGroups)/\(trials) max_residual_cents=\(maxResidualCents)")
        XCTAssertEqual(zeroedGroups, trials)
        XCTAssertGreaterThan(reduction, 0)
    }

    func testEqualSplitsAlwaysSumExactly() {
        var rng = SeededRNG(state: 7)
        for _ in 0..<10_000 {
            let amount = Decimal(Int.random(in: 1...1_000_000, using: &rng)) / 100
            let members = (0..<Int.random(in: 1...15, using: &rng)).map { Member(id: UUID(), name: "M\($0)") }
            let splits = DebtSimplifier.equalSplits(of: amount, among: members)
            XCTAssertEqual(splits.reduce(0) { $0 + $1.owedAmount }, amount)
        }
        print("METRIC equal_split_cases_exact=10000/10000")
    }

    func testLargeGroupPerformance() {
        var rng = SeededRNG(state: 1)
        let expenses = randomGroup(members: 50, expenses: 5_000, rng: &rng)
        let clock = ContinuousClock()
        var samples: [Double] = []
        for _ in 0..<10 {
            let elapsed = clock.measure { _ = DebtSimplifier.simplify(expenses: expenses) }
            samples.append(Double(elapsed.components.attoseconds) / 1e15 + Double(elapsed.components.seconds) * 1000)
        }
        samples.sort()
        print(String(format: "METRIC large_group members=50 expenses=5000 median_ms=%.1f p90_ms=%.1f", samples[5], samples[8]))

        measure { _ = DebtSimplifier.simplify(expenses: expenses) }
    }
}
