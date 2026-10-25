//
//  ExpenseRepositoryTests.swift
//  SplitWiseCloneTests
//
//  The shared write path used by both the form and Siri: exact-cent
//  validation, edits, payments, "me" linking, and guest → Apple relinking.
//

import CoreData
import XCTest
@testable import SplitWiseClone

@MainActor
final class ExpenseRepositoryTests: XCTestCase {
    private var repository: ExpenseRepository!
    private var groupID: UUID!
    private var group: ExpenseGroup { try! repository.group(id: groupID)! }

    override func setUp() async throws {
        let persistence = PersistenceController(inMemory: true)
        repository = ExpenseRepository(context: persistence.container.viewContext, persistence: persistence)
        groupID = try repository.createGroup(name: "Lisbon Trip", memberNames: ["Maya", "Ravi"], me: ("Dhyan", "guest-1"))
    }

    private func member(_ name: String) -> Member { group.members.first { $0.name == name }! }

    private func expense(_ amount: Decimal, paidBy: String, splits: [ExpenseSplit]) -> Expense {
        Expense(id: UUID(), title: "Dinner", amount: amount, currencyCode: "USD", category: .food,
                paidBy: member(paidBy), splits: splits, date: .now)
    }

    func testCreatorIsLinkedAsMe() {
        XCTAssertEqual(group.me("guest-1")?.name, "Dhyan")
        XCTAssertEqual(group.members.count, 3)
    }

    func testEqualSplitOfAwkwardAmountAddsUpExactly() throws {
        let splits = DebtSimplifier.equalSplits(of: 100, among: group.members)
        XCTAssertEqual(splits.map(\.owedAmount).sorted(), [Decimal(string: "33.33")!, Decimal(string: "33.33")!, Decimal(string: "33.34")!])
        try repository.save(expense(100, paidBy: "Dhyan", splits: splits), in: groupID)
        XCTAssertEqual(group.totalSpent, 100)
    }

    func testCustomSplitThatDoesNotAddUpIsRejected() {
        let splits = [ExpenseSplit(id: UUID(), member: member("Maya"), owedAmount: 50),
                      ExpenseSplit(id: UUID(), member: member("Ravi"), owedAmount: 30)]
        XCTAssertThrowsError(try repository.save(expense(84, paidBy: "Dhyan", splits: splits), in: groupID)) { error in
            XCTAssertEqual(error as? ExpenseValidationError, .splitsDontAddUp(total: 84, splits: 80))
        }
        XCTAssertTrue(group.expenses.isEmpty)
    }

    func testRejectsBadAmountsCurrencyAndStrangers() {
        let stranger = Member(id: UUID(), name: "Zed")
        let cases: [(Expense, ExpenseValidationError)] = [
            (expense(0, paidBy: "Dhyan", splits: []), .nonPositiveAmount),
            (expense(Decimal(string: "10.005")!, paidBy: "Dhyan", splits: []), .tooManyDecimals),
            (Expense(id: UUID(), title: "X", amount: 10, currencyCode: "ZZZ", category: .other, paidBy: member("Dhyan"),
                     splits: [ExpenseSplit(id: UUID(), member: member("Dhyan"), owedAmount: 10)], date: .now), .unknownCurrency("ZZZ")),
            (expense(10, paidBy: "Dhyan", splits: [ExpenseSplit(id: UUID(), member: stranger, owedAmount: 10)]), .participantNotInGroup("Zed")),
            (expense(10, paidBy: "Dhyan", splits: []), .noParticipants),
        ]
        for (expense, expected) in cases {
            XCTAssertThrowsError(try ExpenseValidator.validate(expense, in: group)) { XCTAssertEqual($0 as? ExpenseValidationError, expected) }
        }
    }

    func testEditingReplacesSplits() throws {
        var dinner = expense(90, paidBy: "Dhyan", splits: DebtSimplifier.equalSplits(of: 90, among: group.members))
        try repository.save(dinner, in: groupID)
        dinner.amount = 60
        dinner.splits = DebtSimplifier.equalSplits(of: 60, among: [member("Maya"), member("Ravi")])
        try repository.save(dinner, in: groupID)

        XCTAssertEqual(group.expenses.count, 1)
        XCTAssertEqual(group.expenses[0].splits.count, 2)
        XCTAssertEqual(group.balance(of: member("Dhyan")), 60)
    }

    func testRecordedPaymentsDoNotReappear() throws {
        try repository.save(expense(90, paidBy: "Dhyan", splits: DebtSimplifier.equalSplits(of: 90, among: group.members)), in: groupID)
        XCTAssertEqual(group.settlementPlan.count, 2)
        for settlement in group.settlementPlan { try repository.recordPayment(settlement, in: groupID) }
        XCTAssertTrue(group.settlementPlan.isEmpty)
        XCTAssertTrue(group.balances.allSatisfy { $0.amount == 0 })
    }

    func testClaimingMemberMovesTheLink() throws {
        try repository.claimMember(member("Maya").id, in: groupID, userID: "guest-1")
        XCTAssertEqual(group.me("guest-1")?.name, "Maya")
        XCTAssertEqual(group.members.filter { $0.userID == "guest-1" }.count, 1)
    }

    func testGuestSigningInKeepsTheirGroups() throws {
        try repository.relinkUser(from: "guest-1", to: "apple-abc")
        XCTAssertNil(group.me("guest-1"))
        XCTAssertEqual(group.me("apple-abc")?.name, "Dhyan")
    }

    func testDeleteAllDataRemovesOwnGroups() throws {
        try repository.deleteAllData(for: "guest-1")
        XCTAssertTrue(try repository.groups().isEmpty)
    }
}

final class NameMatcherTests: XCTestCase {
    func testSpokenNamesMatchLoosely() {
        XCTAssertTrue(NameMatcher.matches("Maya Patel", spoken: "maya"))
        XCTAssertTrue(NameMatcher.matches("Lisbon Trip", spoken: "the Lisbon trip"))
        XCTAssertTrue(NameMatcher.matches("Zoë", spoken: "zoe"))
        XCTAssertFalse(NameMatcher.matches("Ravi", spoken: "Maya"))
        XCTAssertTrue(NameMatcher.isSelfReference("Me"))
    }

    func testAmbiguousNameReturnsEveryCandidate() {
        let names = ["Sam Lee", "Sam Ortiz", "Ravi"]
        XCTAssertEqual(names.filter { NameMatcher.matches($0, spoken: "Sam") }, ["Sam Lee", "Sam Ortiz"])
    }
}
