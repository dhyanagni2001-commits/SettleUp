//
//  AddExpenseIntent.swift
//  SplitWiseClone
//
//  "Hey Siri, add an expense to Lisbon Trip in SettleUp." Siri collects
//  the details, this intent resolves people against the group, splits
//  with the same DebtSimplifier logic the form uses, validates to the cent,
//  and saves through the shared repository. Anything it can't resolve
//  confidently is asked about, never guessed.
//

import AppIntents
import Foundation

struct AddExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Expense"
    static let description = IntentDescription("Record a shared expense in one of your SettleUp groups.")
    /// Runs in the background; only comes forward when a custom split needs the form.
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    @Parameter(title: "Group", requestValueDialog: "Which group is this for?")
    var group: GroupEntity

    @Parameter(title: "Amount", requestValueDialog: "How much was it?")
    var amount: IntentCurrencyAmount

    @Parameter(title: "Description", requestValueDialog: "What was it for?")
    var title: String

    @Parameter(title: "Paid By", requestValueDialog: "Who paid?")
    var payer: MemberEntity?

    @Parameter(title: "Split Between", requestValueDialog: "Who should it be split between?")
    var participants: [MemberEntity]?

    @Parameter(title: "Split", default: .equal)
    var splitType: SplitType

    @Parameter(title: "Date")
    var date: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$amount) for \(\.$title) to \(\.$group)") {
            \.$payer
            \.$participants
            \.$splitType
            \.$date
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let repository = ExpenseRepository.current
        guard let group = try repository.group(id: group.id) else {
            throw SpokenError("I couldn't find that group in SettleUp.")
        }
        let me = group.me(AccountStore.shared.userID)
        let speak = { (member: Member) in member.id == me?.id ? "you" : member.name }

        let description = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else { throw $title.needsValueError("What was it for?") }

        let total = amount.amount
        guard total > 0 else { throw $amount.needsValueError("How much was it? It needs to be more than zero.") }
        guard ExpenseValidator.hasAtMostTwoDecimals(total) else { throw $amount.needsValueError("How much was it, to the cent?") }
        let currency = (amount.currencyCode.isEmpty ? group.primaryCurrency : amount.currencyCode).uppercased()
        guard ExpenseValidator.isKnownCurrency(currency) else { throw $amount.needsValueError("Which currency was that in?") }

        // Payer: whoever Siri resolved, else the person speaking, else ask.
        let paidBy: Member
        if let payer {
            guard let member = group.members.first(where: { $0.id == payer.id }) else {
                throw $payer.needsValueError("\(payer.name) isn't in \(group.name). Who paid?")
            }
            paidBy = member
        } else if let me {
            paidBy = me
        } else {
            throw $payer.needsValueError("Who paid?")
        }

        // Participants must all be in the group; nobody named means everyone,
        // which is confirmed before saving rather than assumed.
        var splitAmong: [Member] = []
        for participant in participants ?? [] {
            guard let member = group.members.first(where: { $0.id == participant.id }) else {
                throw $participants.needsValueError("\(participant.name) isn't in \(group.name). Who should it be split between?")
            }
            if !splitAmong.contains(member) { splitAmong.append(member) }
        }
        let splitWithEveryone = splitAmong.isEmpty
        if splitWithEveryone { splitAmong = group.members }

        if splitType == .custom {
            let draft = ExpenseDraft(groupID: group.id, title: description, amount: total, currencyCode: currency,
                                     paidByID: paidBy.id, participantIDs: splitAmong.map(\.id), splitType: .custom,
                                     date: date ?? .now)
            try await continueInForeground("Custom amounts are easier to enter on screen. Open SettleUp to finish?")
            AppRouter.shared.review(draft)
            return .result(dialog: "Finish the split in SettleUp.")
        }

        let expense = Expense(
            id: UUID(), title: description, amount: total, currencyCode: currency,
            category: ExpenseCategorizer().categorize(title: description),
            paidBy: paidBy, splits: DebtSimplifier.equalSplits(of: total, among: splitAmong), date: date ?? .now
        )
        do {
            try ExpenseValidator.validate(expense, in: group)
        } catch {
            throw SpokenError(error.localizedDescription)
        }

        let money = total.formatted(.currency(code: currency))
        let people = splitAmong.map(speak).formatted(.list(type: .and))
        if splitWithEveryone {
            try await requestConfirmation(
                actionName: .add,
                dialog: "Add \(money) for \(description) to \(group.name), paid by \(speak(paidBy)) and split equally between \(people)?"
            )
        }

        try repository.save(expense, in: group.id)
        return .result(dialog: "Added \(description) to \(group.name) for \(money), split equally between \(people).")
    }
}
