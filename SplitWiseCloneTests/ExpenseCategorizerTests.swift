//
//  ExpenseCategorizerTests.swift
//  SplitWiseCloneTests
//
//  Covers the keyword-fallback path today; once the trained CoreML
//  model is added, extend these with fixture titles the model should
//  classify correctly (e.g. from a held-out slice of the training CSV).
//

import XCTest
@testable import SplitWiseClone

final class ExpenseCategorizerTests: XCTestCase {
    private let categorizer = ExpenseCategorizer()

    func testTransportKeywords() {
        XCTAssertEqual(categorizer.categorize(title: "Uber to airport"), .transport)
        XCTAssertEqual(categorizer.categorize(title: "Gas station fill-up"), .transport)
    }

    func testFoodKeywords() {
        XCTAssertEqual(categorizer.categorize(title: "Dinner at Nobu"), .food)
        XCTAssertEqual(categorizer.categorize(title: "Coffee run"), .food)
    }

    func testUnknownTitleFallsBackToOther() {
        XCTAssertEqual(categorizer.categorize(title: "xyz123"), .other)
    }
}
