// Trains ExpenseCategoryClassifier.mlmodel with Create ML and writes it into
// SplitWiseClone/ML/, where Xcode compiles it and generates a Swift class.
//
//   python3 TrainingData/generate_dataset.py
//   swift TrainingData/train.swift
//
// Two algorithms are trained and scored on SplitWiseCloneTests/evaluation.csv
// (kept there so the unit tests bundle it), which is
// hand-written and shares no phrasing with the generated training set; the
// better one is kept. Run from the repo root.

import CreateML
import Foundation
import NaturalLanguage

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let trainingURL = root.appending(path: "TrainingData/expense_categories.csv")
let evaluationURL = root.appending(path: "SplitWiseCloneTests/evaluation.csv")
let outputURL = root.appending(path: "SplitWiseClone/ML/ExpenseCategoryClassifier.mlmodel")

let training = try MLDataTable(contentsOf: trainingURL)
// evaluation.csv titles contain no commas, so the label is after the last one.
let evaluationRows: [(text: String, label: String)] = try String(contentsOf: evaluationURL, encoding: .utf8)
    .split(separator: "\n").dropFirst()
    .compactMap { line in
        guard let comma = line.lastIndex(of: ",") else { return nil }
        return (String(line[..<comma]), String(line[line.index(after: comma)...]))
    }

func accuracy(_ classifier: MLTextClassifier) -> Double {
    let correct = evaluationRows.filter { (try? classifier.prediction(from: $0.text)) == $0.label }.count
    return Double(correct) / Double(evaluationRows.count)
}

var candidates: [(name: String, classifier: MLTextClassifier)] = []
for (name, algorithm) in [
    ("maxEnt", MLTextClassifier.ModelAlgorithmType.maxEnt(revision: 1)),
    ("transferLearning", .transferLearning(.elmoEmbedding, revision: 1)),
] {
    let start = Date()
    let classifier = try MLTextClassifier(
        trainingData: training, textColumn: "text", labelColumn: "label",
        parameters: .init(validation: .split(strategy: .automatic), algorithm: algorithm, language: .english)
    )
    let validation = 1 - classifier.validationMetrics.classificationError
    print(String(format: "METRIC model=%@ validation_accuracy=%.3f heldout_accuracy=%.3f train_seconds=%.0f",
                 name, validation, accuracy(classifier), Date().timeIntervalSince(start)))
    candidates.append((name, classifier))
}

let best = candidates.max { accuracy($0.classifier) < accuracy($1.classifier) }!
for row in evaluationRows {
    let predicted = (try? best.classifier.prediction(from: row.text)) ?? "?"
    if predicted != row.label { print("MISS \(row.text) -> \(predicted) (expected \(row.label))") }
}

let metadata = MLModelMetadata(
    author: "SettleUp",
    shortDescription: "Suggests an expense category from its title. Runs on device.",
    version: "1.0"
)
try best.classifier.write(to: outputURL, metadata: metadata)
print("Saved \(best.name) model to \(outputURL.path)")
