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
    @State private var categoryWasPicked = false
    @State private var splitAmong: Set<UUID> = []
    @FocusState private var titleFocused: Bool

    private let categorizer = ExpenseCategorizer()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        CategoryBadge(category: category, size: 44)
                        VStack(alignment: .leading) {
                            TextField("What was it for?", text: $title)
                                .font(.headline)
                                .focused($titleFocused)
                            TextField("0.00", text: $amountText)
                                .keyboardType(.decimalPad)
                                .font(.system(.title, design: .rounded, weight: .bold))
                        }
                    }
                    .onChange(of: title) { _, newValue in
                        // Live on-device category suggestion as the user types,
                        // until they pick one by hand.
                        guard !categoryWasPicked else { return }
                        category = categorizer.categorize(title: newValue)
                    }
                    Picker("Category", selection: Binding(get: { category }, set: { category = $0; categoryWasPicked = true })) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.symbol).tag(cat)
                        }
                    }
                }

                Section("Paid by") {
                    MemberChips(members: group.members, isSelected: { paidBy == $0 }) { paidBy = $0 }
                }

                Section {
                    MemberChips(members: group.members, isSelected: { splitAmong.contains($0.id) }) { member in
                        if splitAmong.contains(member.id) { splitAmong.remove(member.id) } else { splitAmong.insert(member.id) }
                    }
                } header: {
                    Text("Split equally between")
                } footer: {
                    if let share = perPersonShare {
                        Text("\(share, format: .currency(code: "USD")) each")
                            .contentTransition(.numericText())
                            .animation(.snappy, value: share)
                    }
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                paidBy = paidBy ?? group.members.first
                if splitAmong.isEmpty { splitAmong = Set(group.members.map(\.id)) }
                titleFocused = true
            }
        }
    }

    private var amount: Decimal? {
        Decimal(string: amountText, locale: .current).flatMap { $0 > 0 ? $0 : nil }
    }

    private var participants: [Member] {
        group.members.filter { splitAmong.contains($0.id) }
    }

    private var perPersonShare: Decimal? {
        guard let amount, !participants.isEmpty else { return nil }
        return amount / Decimal(participants.count)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && amount != nil && paidBy != nil && !participants.isEmpty
    }

    private func save() {
        guard let amount, let paidBy else { return }
        onAdd(Expense(
            id: UUID(),
            title: title.trimmingCharacters(in: .whitespaces),
            amount: amount,
            currencyCode: "USD",
            category: category,
            paidBy: paidBy,
            splits: DebtSimplifier.equalSplits(of: amount, among: participants),
            date: Date()
        ))
        dismiss()
    }
}

private struct MemberChips: View {
    let members: [Member]
    let isSelected: (Member) -> Bool
    let onTap: (Member) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(members) { member in
                    let selected = isSelected(member)
                    Button {
                        onTap(member)
                    } label: {
                        HStack(spacing: 6) {
                            Avatar(name: member.name, size: 24)
                            Text(member.name).font(.subheadline.weight(.medium))
                        }
                        .padding(.leading, 4).padding(.trailing, 12).padding(.vertical, 4)
                        .background(Capsule().fill(selected ? Color.brand.opacity(0.18) : Color.elevated))
                        .overlay(Capsule().stroke(selected ? Color.brand : .clear, lineWidth: 1.5))
                        .scaleEffect(selected ? 1 : 0.95)
                        .opacity(selected ? 1 : 0.6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selected)
                    .sensoryFeedback(.selection, trigger: selected)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
