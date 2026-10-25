//
//  GroupIntents.swift
//  SplitWiseClone
//
//  Read-only Siri actions (check my balance, show a settlement plan) and
//  opening a group in the app, plus the App Shortcuts phrases for all of them.
//

import AppIntents
import SwiftUI

struct CheckBalanceIntent: AppIntent {
    static let title: LocalizedStringResource = "Check My Balance"
    static let description = IntentDescription("Hear what you owe or are owed, in one group or across all of them.")

    @Parameter(title: "Group")
    var group: GroupEntity?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let userID = AccountStore.shared.userID
        var groups = try ExpenseRepository.current.groups()
        if let group { groups = groups.filter { $0.id == group.id } }
        guard !groups.isEmpty else { throw SpokenError("You don't have any groups in SettleUp yet.") }

        let linked = groups.compactMap { group in group.me(userID).map { (group, $0) } }
        guard !linked.isEmpty else {
            let place = group.map { "in \($0.name)" } ?? "in your groups"
            throw SpokenError("I don't know which person you are \(place) yet. Open the group in SettleUp and tap “This is me”.")
        }

        let summaries = linked.map { group, me in BalanceSummary(group: group, me: me) }
        if summaries.count == 1 {
            return .result(dialog: "\(summaries[0].sentence)")
        }
        let open = summaries.filter { !$0.isSettled }
        if open.isEmpty { return .result(dialog: "You're settled up in all your groups.") }
        return .result(dialog: "\(open.map(\.sentence).joined(separator: " "))")
    }
}

struct ShowSettlementPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Settlement Plan"
    static let description = IntentDescription("See who should pay whom to settle a group.")

    @Parameter(title: "Group", requestValueDialog: "Which group?")
    var group: GroupEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        guard let group = try ExpenseRepository.current.group(id: group.id) else {
            throw SpokenError("I couldn't find that group in SettleUp.")
        }
        let me = group.me(AccountStore.shared.userID)
        let plan = group.settlementPlan
        let speak = { (member: Member) in member.id == me?.id ? "you" : member.name }

        let dialog: String
        if plan.isEmpty {
            dialog = "Everyone in \(group.name) is settled up."
        } else {
            let lines = plan.map { "\(speak($0.from).capitalizedFirst) pays \(speak($0.to)) \($0.amount.formatted(.currency(code: $0.currencyCode)))" }
            dialog = "To settle \(group.name): \(lines.formatted(.list(type: .and)))."
        }
        return .result(dialog: "\(dialog)", view: SettlementSnippet(groupName: group.name, plan: plan, meID: me?.id))
    }
}

struct OpenGroupIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Group"
    static let description = IntentDescription("Open a group in SettleUp.")
    static let supportedModes: IntentModes = .foreground

    @Parameter(title: "Group", requestValueDialog: "Which group?")
    var group: GroupEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.openGroupID = group.id
        return .result()
    }
}

struct SettleUpShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Add an expense to \(\.$group) in \(.applicationName)",
                "Add an expense in \(.applicationName)",
                "Add a \(.applicationName) expense",
                "Split a bill in \(.applicationName)",
            ],
            shortTitle: "Add Expense",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: CheckBalanceIntent(),
            phrases: [
                "Check my balance in \(.applicationName)",
                "What do I owe in \(.applicationName)",
                "Check my \(\.$group) balance in \(.applicationName)",
            ],
            shortTitle: "Check Balance",
            systemImageName: "person.crop.circle.badge.checkmark"
        )
        AppShortcut(
            intent: ShowSettlementPlanIntent(),
            phrases: [
                "Who owes who in \(\.$group) in \(.applicationName)",
                "Show the settlement plan for \(\.$group) in \(.applicationName)",
                "Show a settlement plan in \(.applicationName)",
            ],
            shortTitle: "Settlement Plan",
            systemImageName: "arrow.left.arrow.right"
        )
        AppShortcut(
            intent: OpenGroupIntent(),
            phrases: [
                "Open \(\.$group) in \(.applicationName)",
                "Open a group in \(.applicationName)",
            ],
            shortTitle: "Open Group",
            systemImageName: "rectangle.stack"
        )
    }
}

/// One spoken sentence describing where "me" stands in a group.
private struct BalanceSummary {
    let group: ExpenseGroup
    let me: Member

    private var mine: [Settlement] { group.settlementPlan.filter { $0.from.id == me.id || $0.to.id == me.id } }
    var isSettled: Bool { mine.isEmpty }

    var sentence: String {
        guard !isSettled else { return "You're all settled up in \(group.name)." }
        let parts = mine.map { settlement in
            let money = settlement.amount.formatted(.currency(code: settlement.currencyCode))
            return settlement.from.id == me.id ? "you owe \(settlement.to.name) \(money)" : "\(settlement.from.name) owes you \(money)"
        }
        return "In \(group.name), \(parts.formatted(.list(type: .and)))."
    }
}

/// Compact plan shown under Siri's answer.
private struct SettlementSnippet: View {
    let groupName: String
    let plan: [Settlement]
    let meID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(groupName).font(.headline)
            if plan.isEmpty {
                Label("All settled up", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Color.brand)
            }
            ForEach(plan, id: \.pairKey) { settlement in
                HStack(spacing: 8) {
                    Avatar(name: settlement.from.name, size: 26)
                    Image(systemName: "arrow.right").font(.caption.bold()).foregroundStyle(.secondary)
                    Avatar(name: settlement.to.name, size: 26)
                    Text("\(label(settlement.from)) → \(label(settlement.to))")
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer()
                    Text(settlement.amount, format: .currency(code: settlement.currencyCode))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
            }
        }
        .padding()
    }

    private func label(_ member: Member) -> String { member.id == meID ? "You" : member.name }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
