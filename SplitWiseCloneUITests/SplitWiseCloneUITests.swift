//
//  SplitWiseCloneUITests.swift
//  SplitWiseCloneUITests
//

import XCTest

final class SplitWiseCloneUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        XCTAssertTrue(app.navigationBars["SettleUp"].waitForExistence(timeout: 5))
    }

    func testCreateGroupAddExpenseAndSettle() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        app.navigationBars["SettleUp"].buttons["New Group"].tap()
        app.textFields["Group name"].tap()
        app.typeText("Trip")
        for name in ["Ana", "Ben"] {
            app.textFields["Add member"].tap()
            app.typeText(name + "\n")
        }
        app.buttons["Create"].tap()

        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Trip")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        sleep(1) // let the entrance animation finish
        card.tap()
        XCTAssertTrue(app.buttons["Add Expense"].waitForExistence(timeout: 5))
        app.buttons["Add Expense"].tap()
        app.textFields["What was it for?"].tap()
        app.typeText("Dinner")
        app.textFields["0.00"].tap()
        app.typeText("40")
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Ben pays Ana"].waitForExistence(timeout: 5))
        app.buttons["Settle"].tap()
        XCTAssertTrue(app.staticTexts["All settled up"].waitForExistence(timeout: 5))
    }
}
