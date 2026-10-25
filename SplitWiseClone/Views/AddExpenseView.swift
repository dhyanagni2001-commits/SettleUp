//
//  AddExpenseView.swift
//  SplitWiseClone
//
//  Add or edit an expense. Also where Siri hands off drafts it couldn't
//  finish (custom amounts). Validation is the same ExpenseValidator the
//  Siri path uses, so both enforce exact-to-the-cent splits.
//

import SwiftUI

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    let group: ExpenseGroup
    var existing: Expense? = nil
    var draft: ExpenseDraft? = nil
    var defaultPayer: Member? = nil
    let onSave: (Expense) -> Void

    @State private var title = ""
    @State private var amountText = ""
    @State private var currencyCode = "USD"
    @State private var date = Date()
    @State private var paidBy: Member?
    @State private var category: ExpenseCategory = .other
    @State private var categoryWasPicked = false
    @State private var splitType: SplitType = .equal
    @State private var splitAmong: Set<UUID> = []
    @State private var customAmounts: [UUID: String] = [:]
    @State private var errorMessage: String?
    @State private var shake = 0
    @State private var didPrefill = false
    @FocusState private var titleFocused: Bool

    private let categorizer = ExpenseCategorizer()
    private static let currencies = ["USD", "EUR", "GBP", "INR", "CAD", "AUD", "JPY", "CHF", "SGD", "MXN"]

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
                            HStack {
                                TextField("0.00", text: $amountText)
                                    .keyboardType(.decimalPad)
                                    .font(.system(.title, design: .rounded, weight: .bold))
                                Picker("Currency", selection: $currencyCode) {
                                    ForEach(currencyOptions, id: \.self) { Text($0).tag($0) }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .fixedSize()
                            }
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
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Paid by") {
                    MemberChips(members: group.members, isSelected: { paidBy == $0 }) { paidBy = $0 }
                }

                Section {
                    Picker("Split", selection: $splitType.animation(.smooth(duration: 0.3))) {
                        Text("Equally").tag(SplitType.equal)
                        Text("Custom amounts").tag(SplitType.custom)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                    if splitType == .equal {
                        MemberChips(members: group.members, isSelected: { splitAmong.contains($0.id) }) { member in
                            if splitAmong.contains(member.id) { splitAmong.remove(member.id) } else { splitAmong.insert(member.id) }
                        }
                        .transition(.opacity)
                    } else {
                        ForEach(group.members) { member in
                            HStack(spacing: 10) {
                                Avatar(name: member.name, size: 28)
                                Text(member.name)
                                Spacer()
                                TextField("0.00", text: Binding(
                                    get: { customAmounts[member.id] ?? "" },
                                    set: { customAmounts[member.id] = $0 }
                                ))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.body.monospacedDigit())
                                .frame(width: 100)
                                .accessibilityLabel("\(member.name)'s share")
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                } header: {
                    Text("Split")
                } footer: {
                    splitFooter
                        .contentTransition(.numericText())
                        .animation(.smooth, value: splitFooterKey)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(Color.negative)
                            .modifier(Shake(trigger: shake))
                    }
                    .transition(.opacity)
                }
            }
            .animation(.smooth(duration: 0.3), value: errorMessage)
            .navigationTitle(existing == nil ? "Add Expense" : "Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .sensoryFeedback(.error, trigger: shake)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: prefill)
        }
    }

    // MARK: Derived values

    private var currencyOptions: [String] {
        Self.currencies.contains(currencyCode) ? Self.currencies : [currencyCode] + Self.currencies
    }

    private var amount: Decimal? {
        Self.parse(amountText).flatMap { $0 > 0 ? $0 : nil }
    }

    private var participants: [Member] {
        group.members.filter { splitAmong.contains($0.id) }
    }

    private var splits: [ExpenseSplit] {
        switch splitType {
        case .equal:
            guard let amount else { return [] }
            return DebtSimplifier.equalSplits(of: amount, among: participants)
        case .custom:
            return group.members.compactMap { member in
                guard let share = Self.parse(customAmounts[member.id] ?? ""), share > 0 else { return nil }
                return ExpenseSplit(id: UUID(), member: member, owedAmount: share)
            }
        }
    }

    private var customRemaining: Decimal {
        (amount ?? 0) - splits.reduce(0) { $0 + $1.owedAmount }
    }

    private var splitFooterKey: String { "\(splitType)-\(amountText)-\(splitAmong.count)-\(customRemaining)" }

    @ViewBuilder private var splitFooter: some View {
        switch splitType {
        case .equal:
            let shares = splits.map(\.owedAmount)
            if let high = shares.max(), let low = shares.min() {
                if high == low {
                    Text("\(high, format: .currency(code: currencyCode)) each")
                } else {
                    Text("\(high, format: .currency(code: currencyCode)) or \(low, format: .currency(code: currencyCode)) each, so it adds up exactly")
                }
            }
        case .custom:
            if customRemaining == 0, amount != nil {
                Label("Adds up to the total", systemImage: "checkmark.circle.fill").foregroundStyle(Color.brand)
            } else if customRemaining > 0 {
                Text("\(customRemaining, format: .currency(code: currencyCode)) left to assign")
            } else {
                Text("\(-customRemaining, format: .currency(code: currencyCode)) over the total").foregroundStyle(Color.negative)
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && amount != nil && paidBy != nil && !splits.isEmpty
    }

    // MARK: Actions

    private func prefill() {
        defer { titleFocused = existing == nil && draft?.title.isEmpty != false }
        guard !didPrefill else { return }
        didPrefill = true
        currencyCode = group.primaryCurrency

        if let existing {
            title = existing.title
            amountText = Self.format(existing.amount)
            currencyCode = existing.currencyCode
            date = existing.date
            paidBy = existing.paidBy
            category = existing.category
            categoryWasPicked = true
            splitType = existing.splitType
            splitAmong = Set(existing.splits.map(\.member.id))
            customAmounts = Dictionary(uniqueKeysWithValues: existing.splits.map { ($0.member.id, Self.format($0.owedAmount)) })
        } else if let draft {
            title = draft.title
            amountText = draft.amount.map { Self.format($0) } ?? ""
            currencyCode = draft.currencyCode
            date = draft.date
            paidBy = group.members.first { $0.id == draft.paidByID } ?? defaultPayer ?? group.members.first
            splitType = draft.splitType
            splitAmong = Set(draft.participantIDs.isEmpty ? group.members.map(\.id) : draft.participantIDs)
        } else {
            paidBy = defaultPayer ?? group.members.first
            splitAmong = Set(group.members.map(\.id))
        }
    }

    private func save() {
        guard let amount, let paidBy else { return }
        let expense = Expense(
            id: existing?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespaces),
            amount: amount,
            currencyCode: currencyCode,
            category: category,
            paidBy: paidBy,
            splits: splits,
            date: date
        )
        do {
            try ExpenseValidator.validate(expense, in: group)
        } catch {
            errorMessage = error.localizedDescription
            withAnimation(.linear(duration: 0.4)) { shake += 1 }
            return
        }
        onSave(expense)
        dismiss()
    }

    private static func parse(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return Decimal(string: trimmed, locale: .current) ?? Decimal(string: trimmed)
    }

    private static func format(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }
}

/// Small horizontal wobble when validation fails.
private struct Shake: GeometryEffect {
    var trigger: Int
    var animatableData: CGFloat

    init(trigger: Int) {
        self.trigger = trigger
        animatableData = CGFloat(trigger)
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 6 * sin(animatableData * .pi * 4), y: 0))
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
                        .scaleEffect(selected ? 1 : 0.96)
                        .opacity(selected ? 1 : 0.6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
                    .sensoryFeedback(.selection, trigger: selected)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
