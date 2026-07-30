//
//  ExpenseCategorizer.swift
//  SplitWiseClone
//
//  Wraps an on-device CoreML text classifier (trained with Apple
//  CreateML on a small labeled dataset of expense titles -> category)
//  so category suggestions never leave the device.
//
//  TODO: train the actual model.
//    1. Build a CSV with two columns: `text` (expense title, e.g.
//       "Uber to airport") and `label` (an ExpenseCategory rawValue).
//    2. Open Create ML.app -> new Text Classifier project -> import
//       the CSV -> train -> export as ExpenseCategoryClassifier.mlmodel.
//    3. Drag the .mlmodel into the Xcode project (this ML/ folder);
//       Xcode auto-generates a Swift class with the same name.
//

import CoreML
import Foundation

enum CategorizerError: Error {
    case modelUnavailable
}

final class ExpenseCategorizer {

    /// Set to `false` in DEBUG until the trained .mlmodel is added to the
    /// project, so the rest of the app can build and run against the
    /// keyword fallback below.
    private let modelIsAvailable = false

    /// Returns a best-guess category for a freeform expense title.
    /// Runs entirely on-device — no network call, no data leaves the phone.
    func categorize(title: String) -> ExpenseCategory {
        if modelIsAvailable {
            // TODO: replace with real inference once the model is added, e.g.:
            //   let model = try ExpenseCategoryClassifier(configuration: MLModelConfiguration())
            //   let prediction = try model.prediction(text: title)
            //   return ExpenseCategory(rawValue: prediction.label) ?? .other
        }
        return keywordFallback(for: title)
    }

    /// Simple keyword heuristic used until the CreateML model is trained,
    /// and as a safety-net fallback if inference ever fails.
    private func keywordFallback(for title: String) -> ExpenseCategory {
        let lowercased = title.lowercased()

        let keywordMap: [(keywords: [String], category: ExpenseCategory)] = [
            (["uber", "lyft", "taxi", "gas", "parking", "flight", "train"], .transport),
            (["restaurant", "coffee", "dinner", "lunch", "breakfast", "bar"], .food),
            (["hotel", "airbnb", "motel", "resort"], .lodging),
            (["movie", "concert", "ticket", "show"], .entertainment),
            (["electric", "water bill", "internet", "wifi", "utility"], .utilities),
            (["grocery", "groceries", "supermarket", "market"], .groceries),
        ]

        for entry in keywordMap {
            if entry.keywords.contains(where: lowercased.contains) {
                return entry.category
            }
        }
        return .other
    }
}
