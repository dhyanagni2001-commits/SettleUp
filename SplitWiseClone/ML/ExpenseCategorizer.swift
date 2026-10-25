//
//  ExpenseCategorizer.swift
//  SplitWiseClone
//
//  Suggests a category for an expense title with an on-device Core ML text
//  classifier (ExpenseCategoryClassifier.mlmodel, trained with Create ML by
//  TrainingData/train.swift). Nothing leaves the device.
//
//  The model is only trusted when it's confident; titles it hasn't seen
//  anything like (e.g. a shop name) fall back to a keyword heuristic, and
//  then to "Other", rather than a confident-looking wrong guess.
//

import CoreML
import Foundation
import NaturalLanguage

final class ExpenseCategorizer {
    /// Below this probability the model's guess isn't used. Seven categories
    /// make a blind guess ~14%, so 0.3 filters gibberish while keeping nearly
    /// all of the model's accuracy (see ExpenseCategorizerTests' METRIC lines).
    static let confidenceThreshold = 0.3

    /// Loaded once and shared; nil if the compiled model is missing from the bundle.
    private static let model: NLModel? = {
        guard let url = Bundle.main.url(forResource: "ExpenseCategoryClassifier", withExtension: "mlmodelc"),
              let mlModel = try? MLModel(contentsOf: url)
        else { return nil }
        return try? NLModel(mlModel: mlModel)
    }()

    var isModelAvailable: Bool { Self.model != nil }

    /// Returns a best-guess category for a freeform expense title.
    func categorize(title: String) -> ExpenseCategory {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return .other }
        if let guess = prediction(for: title), guess.confidence >= Self.confidenceThreshold {
            return guess.category
        }
        return keywordFallback(for: title)
    }

    /// The model's top category and its probability, if the model is available.
    func prediction(for title: String) -> (category: ExpenseCategory, confidence: Double)? {
        guard let model = Self.model,
              let (label, confidence) = model.predictedLabelHypotheses(for: title, maximumCount: 1).max(by: { $0.value < $1.value }),
              let category = ExpenseCategory(rawValue: label)
        else { return nil }
        return (category, confidence)
    }

    /// Simple keyword heuristic for titles the model is unsure about, and a
    /// safety net if the model can't be loaded.
    func keywordFallback(for title: String) -> ExpenseCategory {
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
