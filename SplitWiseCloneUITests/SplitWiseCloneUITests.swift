//
//  SplitWiseCloneUITests.swift
//  SplitWiseCloneUITests
//
//  Scaffolded, empty for now — fill in once the Core Data model and
//  real fetch requests are wired up in GroupListViewModel.
//

import XCTest

final class SplitWiseCloneUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["Groups"].waitForExistence(timeout: 5))
    }
}
