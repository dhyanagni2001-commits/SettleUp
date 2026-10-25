//
//  SplitWiseCloneUITests.swift
//  SplitWiseCloneUITests
//

import XCTest

final class SplitWiseCloneUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// -uiTesting starts signed out with an empty in-memory store.
    private func launchAsGuest(named name: String = "Sam") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Shared expenses, settled simply."].waitForExistence(timeout: 5))
        app.buttons["startButton"].tap()
        let nameField = app.textFields["Your name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        // Submit with Return: a fresh simulator's keyboard intro also has a "Continue" button.
        nameField.typeText(name + "\n")
        XCTAssertTrue(app.navigationBars["SettleUp"].waitForExistence(timeout: 5))
        return app
    }

    func testWelcomeShowsSignInOptions() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["SettleUp"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["startButton"].exists)
        XCTAssertFalse(app.secureTextFields.firstMatch.exists, "No password form")
    }

    func testCreateGroupAddExpenseAndSettle() throws {
        let app = launchAsGuest()

        app.navigationBars["SettleUp"].buttons["New Group"].tap()
        app.textFields["Group name"].tap()
        app.typeText("Trip")
        app.textFields["Add member"].tap()
        app.typeText("Ana\n")
        app.buttons["Create"].tap()

        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Trip")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        sleep(1) // let the entrance animation finish
        card.tap()

        // The creator is "me", so the default payer is Sam.
        XCTAssertTrue(app.buttons["Add Expense"].waitForExistence(timeout: 5))
        app.buttons["Add Expense"].tap()
        app.textFields["What was it for?"].tap()
        app.typeText("Dinner")
        app.textFields["0.00"].firstMatch.tap()
        app.typeText("40")
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Ana pays Sam"].waitForExistence(timeout: 5))
        app.buttons["Settle"].tap()
        XCTAssertTrue(app.staticTexts["All settled up"].waitForExistence(timeout: 5))
    }

    /// Full journey: onboarding → group → equal and custom expenses (with a
    /// split that doesn't add up being caught) → edit → settle → account → Siri help.
    /// Screenshots are attached for the README.
    func testFullJourney() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        XCTAssertTrue(app.buttons["startButton"].waitForExistence(timeout: 5))
        app.buttons["startButton"].tap()
        XCTAssertTrue(app.textFields["Your name"].waitForExistence(timeout: 5))
        app.textFields["Your name"].typeText("Dhyan\n")

        app.navigationBars["SettleUp"].buttons["New Group"].tap()
        app.textFields["Group name"].tap()
        app.typeText("Lisbon Trip")
        for name in ["Maya", "Ravi"] {
            app.textFields["Add member"].tap()
            app.typeText(name + "\n")
        }
        app.buttons["Create"].tap()
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Lisbon Trip")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        sleep(1)
        card.tap()

        // Equal split, paid by me (the creator).
        XCTAssertTrue(app.buttons["Add Expense"].waitForExistence(timeout: 5))
        app.buttons["Add Expense"].tap()
        app.textFields["What was it for?"].tap()
        app.typeText("Dinner at Time Out")
        app.textFields["0.00"].firstMatch.tap()
        app.typeText("84")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Ravi pays Dhyan"].waitForExistence(timeout: 5))

        // Custom split that's $50 short is rejected, then fixed.
        app.buttons["Add Expense"].tap()
        app.textFields["What was it for?"].tap()
        app.typeText("Airbnb")
        app.textFields["0.00"].firstMatch.tap()
        app.typeText("300")
        app.buttons["Custom amounts"].tap()
        for (name, share) in [("Dhyan", "100"), ("Maya", "100"), ("Ravi", "50")] {
            app.textFields["\(name)'s share"].tap()
            app.typeText(share)
        }
        app.buttons["Save"].tap()
        let mismatch = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "add up to")).firstMatch
        XCTAssertTrue(mismatch.waitForExistence(timeout: 5))
        // Tap the trailing edge so the cursor sits after "50" before deleting it.
        app.textFields["Ravi's share"].coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        app.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "100")
        XCTAssertTrue(app.staticTexts["Adds up to the total"].waitForExistence(timeout: 3))
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Maya pays Dhyan"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Airbnb"].exists)

        // Editing opens the same form, prefilled.
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Dinner at Time Out")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Edit Expense"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["What was it for?"].value as? String, "Dinner at Time Out")
        app.buttons["Cancel"].tap()

        app.swipeUp()
        app.swipeDown()

        // Settle everything; nothing should come back.
        while app.buttons["Settle"].firstMatch.waitForExistence(timeout: 2) {
            app.buttons["Settle"].firstMatch.tap()
            sleep(1)
        }
        XCTAssertTrue(app.staticTexts["All settled up"].waitForExistence(timeout: 5))

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["settled up"].waitForExistence(timeout: 5))

        app.buttons["Account"].tap()
        XCTAssertTrue(app.buttons["Sign Out"].waitForExistence(timeout: 5))
        app.buttons["Siri & Shortcuts"].tap()
        XCTAssertTrue(app.navigationBars["Siri & Shortcuts"].waitForExistence(timeout: 5))
    }

    /// Captures the README screenshots from the seeded demo groups. Export with
    /// `xcrun xcresulttool export attachments` and copy into docs/screenshots.
    func testREADMEScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-demoData"]
        app.launch()
        XCTAssertTrue(app.buttons["startButton"].waitForExistence(timeout: 5))
        sleep(2)
        snapshot(app, "welcome")
        app.buttons["startButton"].tap()
        XCTAssertTrue(app.textFields["Your name"].waitForExistence(timeout: 5))
        app.textFields["Your name"].typeText("Dhyan\n")

        // Demo groups predate the profile, so claim "me" in each one.
        for group in ["Ski Weekend", "Flat 4B", "Lisbon Trip"] {
            openGroup(group, in: app)
            let claim = app.buttons["This is me: Dhyan"]
            XCTAssertTrue(claim.waitForExistence(timeout: 5))
            claim.tap()
            XCTAssertTrue(app.staticTexts["You"].waitForExistence(timeout: 5))
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        XCTAssertTrue(app.staticTexts["you owe"].waitForExistence(timeout: 5))
        sleep(2)
        snapshot(app, "groups")

        openGroup("Lisbon Trip", in: app)
        XCTAssertTrue(app.staticTexts["Maya pays Dhyan"].waitForExistence(timeout: 5))
        sleep(2)
        snapshot(app, "group-detail")
        app.swipeUp()
        sleep(1)
        snapshot(app, "balances-expenses")
        app.swipeDown()

        // The Core ML model picks the category icon as the title is typed.
        app.buttons["Add Expense"].tap()
        app.textFields["What was it for?"].tap()
        app.typeText("Sunset boat tour")
        app.textFields["0.00"].firstMatch.tap()
        app.typeText("120")
        sleep(1)
        snapshot(app, "add-expense")
        app.buttons["Cancel"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        openGroup("Ski Weekend", in: app)
        while app.buttons["Settle"].firstMatch.waitForExistence(timeout: 2) {
            app.buttons["Settle"].firstMatch.tap()
            sleep(1)
        }
        XCTAssertTrue(app.staticTexts["All settled up"].waitForExistence(timeout: 5))
        snapshot(app, "settled")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["Account"].tap()
        XCTAssertTrue(app.buttons["Sign Out"].waitForExistence(timeout: 5))
        sleep(1)
        snapshot(app, "account")
        app.buttons["Siri & Shortcuts"].tap()
        XCTAssertTrue(app.navigationBars["Siri & Shortcuts"].waitForExistence(timeout: 5))
        sleep(1)
        snapshot(app, "siri")
    }

    private func openGroup(_ name: String, in app: XCUIApplication) {
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        sleep(1)
        card.tap()
        XCTAssertTrue(app.buttons["Add Expense"].waitForExistence(timeout: 5))
    }

    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testAccountScreenSignOutReturnsToWelcome() throws {
        let app = launchAsGuest()
        app.buttons["Account"].tap()
        XCTAssertTrue(app.buttons["Sign Out"].waitForExistence(timeout: 5))
        app.buttons["Sign Out"].tap()
        app.sheets.buttons["Sign Out"].firstMatch.tap()
        XCTAssertTrue(app.buttons["startButton"].waitForExistence(timeout: 5))
    }
}
