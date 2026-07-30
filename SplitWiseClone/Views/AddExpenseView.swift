//
//  AddExpenseView.swift
//  SplitWiseClone
//

import SwiftUI

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    let group: ExpenseGroup
    let onAdd: (Expense) -> Void

    @State private var title = ""
    @State private var amountText = ""
    @State private var paidBy: Member?
    @State private var category: ExpenseCategory = .other

    private let categorizer = ExpenseCategorizer()

    var body: some View {
        NavigationStack {
            Form {
                Section("Expense") {
                    TextField("Title", text: $title)
                        .onChange(of: title) { _, newValue in
                            // Live on-device category suggestion as the user types.
                            category = categorizer.categorize(title: newValue)
                        }
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                    Picker("Category", selection: $category) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                }
                Section("Paid by") {
                    Picker("Paid by", selection: $paidBy) {
                        ForEach(group.members) { member in
                            Text(member.name).tag(Optional(member))
                        }
                    }
                }
                Section {
                    Text("Splits equally among all \(group.members.count) members. Custom splits can be added later.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && Decimal(string: amountText) != nil
            && paidBy != nil
    }

    private func save() {
        guard let amount = Decimal(string: amountText), let paidBy else { return }

        let splitAmount = (amount as NSDecimalNumber)
            .dividing(by: NSDecimalNumber(value: group.members.count))
        let splits = group.members.map {
            ExpenseSplit(id: UUID(), member: $0, owedAmount: splitAmount.decimalValue)
        }

        let expense = Expense(
            id: UUID(),
            title: title,
            amount: amount,
            currencyCode: "USD",
            category: category,
            paidBy: paidBy,
            splits: splits,
            date: Date()
        )
        onAdd(expense)
        dismiss()
    }
}
