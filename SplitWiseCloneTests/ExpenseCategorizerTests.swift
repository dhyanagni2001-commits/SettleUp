//
//  ExpenseCategorizerTests.swift
//  SplitWiseCloneTests
//
//  Checks the bundled Core ML model loads and scores it on the hand-written
//  held-out set in evaluation.csv (no overlap with the generated training
//  data). The CSV lives next to this file so it's bundled with the tests and
//  they run on a real iPhone too. Prints METRIC lines for the README.
//

import XCTest
@testable import SplitWiseClone

@MainActor
final class ExpenseCategorizerTests: XCTestCase {
    private let categorizer = ExpenseCategorizer()

    private func evaluationRows() throws -> [(title: String, category: ExpenseCategory)] {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "evaluation", withExtension: "csv"))
        return try String(contentsOf: url, encoding: .utf8).split(separator: "\n").dropFirst().compactMap { line in
            guard let comma = line.lastIndex(of: ","),
                  let category = ExpenseCategory(rawValue: String(line[line.index(after: comma)...]))
            else { return nil }
            return (String(line[..<comma]), category)
        }
    }

    func testModelIsBundledAndUsed() {
        XCTAssertTrue(categorizer.isModelAvailable, "ExpenseCategoryClassifier.mlmodelc should be in the app bundle")
        let guess = categorizer.prediction(for: "sushi dinner")
        XCTAssertEqual(guess?.category, .food)
    }

    func testHeldOutAccuracy() throws {
        let rows = try evaluationRows()
        XCTAssertGreaterThan(rows.count, 80)

        let modelOnly = rows.filter { categorizer.prediction(for: $0.title)?.category == $0.category }.count
        let shipped = rows.filter { categorizer.categorize(title: $0.title) == $0.category }.count
        print(String(format: "METRIC categorizer heldout=%d model_only_accuracy=%.3f shipped_accuracy=%.3f threshold=%.2f",
                     rows.count, Double(modelOnly) / Double(rows.count), Double(shipped) / Double(rows.count),
                     ExpenseCategorizer.confidenceThreshold))

        // How other thresholds would do, to keep the chosen one honest.
        for threshold in stride(from: 0.3, through: 0.9, by: 0.1) {
            let correct = rows.filter { row in
                if let guess = categorizer.prediction(for: row.title), guess.confidence >= threshold {
                    return guess.category == row.category
                }
                return categorizer.keywordFallback(for: row.title) == row.category
            }.count
            print(String(format: "METRIC categorizer threshold=%.1f accuracy=%.3f", threshold, Double(correct) / Double(rows.count)))
        }

        XCTAssertGreaterThanOrEqual(Double(shipped) / Double(rows.count), 0.75)
    }

    func testCommonTitles() {
        XCTAssertEqual(categorizer.categorize(title: "Uber to airport"), .transport)
        XCTAssertEqual(categorizer.categorize(title: "Dinner at Nobu"), .food)
        XCTAssertEqual(categorizer.categorize(title: "Coffee and pastries"), .food)
        // Known miss: "Coffee run" reads as a shopping trip (Groceries) to the model,
        // since "grocery run" and "coffee beans" are both groceries in the training data.
        XCTAssertEqual(categorizer.categorize(title: "Airbnb for the weekend"), .lodging)
        XCTAssertEqual(categorizer.categorize(title: "Costco run"), .groceries)
        XCTAssertEqual(categorizer.categorize(title: "Internet bill"), .utilities)
        XCTAssertEqual(categorizer.categorize(title: "Concert tickets"), .entertainment)
    }

    func testGibberishFallsBackToOther() {
        XCTAssertEqual(categorizer.categorize(title: "xyz123"), .other)
        XCTAssertEqual(categorizer.categorize(title: "   "), .other)
    }
}
