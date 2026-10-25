//
//  SiriIntentTests.swift
//  SplitWiseCloneTests
//
//  Runs the App Intents the way Siri would after resolving parameters, and
//  checks what lands in the store. Uses the same in-memory store the app
//  uses under test, via ExpenseRepository.current.
//

import AppIntents
import XCTest
@testable import SplitWiseClone

@MainActor
final class SiriIntentTests: XCTestCase {
    private let repository = ExpenseRepository.current
    private var group: ExpenseGroup!

    override func setUp() async throws {
        try repository.deleteAllData(for: nil)
        let account = AccountStore.shared
        account.continueAsGuest()
        account.updateProfile(displayName: "Dhyan", avatarData: nil)
        let id = try repository.createGroup(name: "Lisbon Trip", memberNames: ["Maya", "Ravi"],
                                            me: ("Dhyan", account.userID!))
        group = try repository.group(id: id)
    }

    private func entity(_ name: String) -> MemberEntity {
        MemberEntity(group.members.first { $0.name == name }!, in: group, userID: AccountStore.shared.userID)
    }

    private func addExpenseIntent(_ amount: Decimal, _ title: String, splitWith names: [String]) -> AddExpenseIntent {
        let intent = AddExpenseIntent()
        intent.group = GroupEntity(group)
        intent.amount = IntentCurrencyAmount(amount: amount, currencyCode: "USD")
        intent.title = title
        intent.participants = names.map(entity)
        intent.splitType = .equal
        return intent
    }

    private var saved: ExpenseGroup { try! repository.group(id: group.id)! }

    func testDinnerSplitBetweenMeMayaAndRavi() async throws {
        // "Add an $84 dinner expense to Lisbon Trip, split equally between me, Maya, and Ravi."
        _ = try await addExpenseIntent(84, "Dinner", splitWith: ["Dhyan", "Maya", "Ravi"]).perform()

        let expense = try XCTUnwrap(saved.expenses.first)
        XCTAssertEqual(expense.title, "Dinner")
        XCTAssertEqual(expense.paidBy.name, "Dhyan", "No payer spoken → the person talking to Siri")
        XCTAssertEqual(expense.splits.map(\.owedAmount), [28, 28, 28])
        XCTAssertEqual(expense.category, .food, "Same categorizer as the form")
        XCTAssertEqual(saved.balance(of: saved.me(AccountStore.shared.userID)!), 56)
    }

    func testLeftoverCentsStillAddUp() async throws {
        _ = try await addExpenseIntent(100, "Tickets", splitWith: ["Dhyan", "Maya", "Ravi"]).perform()
        let splits = try XCTUnwrap(saved.expenses.first).splits.map(\.owedAmount)
        XCTAssertEqual(splits.reduce(0, +), 100)
        XCTAssertEqual(Set(splits), [Decimal(string: "33.34")!, Decimal(string: "33.33")!])
    }

    func testExplicitPayerIsUsed() async throws {
        let intent = addExpenseIntent(30, "Taxi", splitWith: ["Maya", "Ravi"])
        intent.payer = entity("Maya")
        _ = try await intent.perform()
        XCTAssertEqual(saved.expenses.first?.paidBy.name, "Maya")
        XCTAssertEqual(saved.settlementPlan.map { "\($0.from.name)→\($0.to.name) \($0.amount)" }, ["Ravi→Maya 15"])
    }

    func testRejectsAmountWithFractionsOfACent() async {
        do {
            _ = try await addExpenseIntent(Decimal(string: "10.005")!, "Coffee", splitWith: ["Maya"]).perform()
            XCTFail("Should ask for a valid amount")
        } catch {}
        XCTAssertTrue(saved.expenses.isEmpty)
    }

    func testPersonFromAnotherGroupIsRejected() async throws {
        let otherID = try repository.createGroup(name: "Flat", memberNames: ["Zed"], me: nil)
        let other = try XCTUnwrap(repository.group(id: otherID))
        let intent = addExpenseIntent(20, "Snacks", splitWith: ["Maya"])
        intent.participants = [MemberEntity(other.members[0], in: other, userID: nil)]
        do {
            _ = try await intent.perform()
            XCTFail("Should ask who to split with")
        } catch {}
        XCTAssertTrue(saved.expenses.isEmpty)
    }

    func testAsksWhoPaidWhenItDoesNotKnowWhoYouAre() async throws {
        let id = try repository.createGroup(name: "Old Group", memberNames: ["Ana", "Ben"], me: nil)
        group = try repository.group(id: id)
        do {
            _ = try await addExpenseIntent(10, "Lunch", splitWith: ["Ana", "Ben"]).perform()
            XCTFail("Should ask who paid instead of guessing")
        } catch {}
        XCTAssertTrue(saved.expenses.isEmpty)
    }

    func testBalanceAndSettlementPlanIntentsRun() async throws {
        _ = try await addExpenseIntent(90, "Groceries", splitWith: ["Dhyan", "Maya", "Ravi"]).perform()

        let balance = CheckBalanceIntent()
        balance.group = GroupEntity(saved)
        _ = try await balance.perform()

        let plan = ShowSettlementPlanIntent()
        plan.group = GroupEntity(saved)
        _ = try await plan.perform()
        XCTAssertEqual(saved.settlementPlan.count, 2)
    }

    func testQueriesFindGroupsAndKeepAmbiguousPeople() async throws {
        try repository.addMember(named: "Maya Patel", to: group.id)
        let groups = try await GroupQuery().entities(matching: "lisbon")
        XCTAssertEqual(groups.map(\.name), ["Lisbon Trip"])

        let mayas = try await MemberQuery().entities(matching: "Maya").map(\.name).sorted()
        XCTAssertEqual(mayas, ["Maya", "Maya Patel"], "Both returned so Siri asks which one")

        let me = try await MemberQuery().entities(matching: "me")
        XCTAssertEqual(me.map(\.name), ["Dhyan"])
    }

    func testOpenGroupRoutesTheApp() async throws {
        let intent = OpenGroupIntent()
        intent.group = GroupEntity(group)
        _ = try await intent.perform()
        XCTAssertEqual(AppRouter.shared.openGroupID, group.id)
        AppRouter.shared.openGroupID = nil
    }
}
