//
//  IntentEntities.swift
//  SplitWiseClone
//
//  How groups and members look to Siri and Shortcuts. Queries return every
//  plausible match for a spoken name rather than picking one, so when
//  "Sam" could be two people Siri asks which one was meant.
//

import AppIntents
import CoreData
import Foundation

struct GroupEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Group"
    static let defaultQuery = GroupQuery()

    let id: UUID
    let name: String
    let memberNames: [String]

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(memberNames.formatted(.list(type: .and)))")
    }

    init(_ group: ExpenseGroup) {
        id = group.id
        name = group.name
        memberNames = group.members.map(\.name)
    }
}

struct GroupQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [GroupEntity] {
        try ExpenseRepository.current.groups().filter { identifiers.contains($0.id) }.map(GroupEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [GroupEntity] {
        try ExpenseRepository.current.groups()
            .filter { NameMatcher.matches($0.name, spoken: string) }
            .map(GroupEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [GroupEntity] {
        try ExpenseRepository.current.groups().map(GroupEntity.init)
    }
}

struct MemberEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Person"
    static let defaultQuery = MemberQuery()

    let id: UUID
    let name: String
    let groupName: String
    let isMe: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: isMe ? "You · \(groupName)" : "\(groupName)",
                              synonyms: isMe ? ["me", "myself", "I"] : [])
    }

    init(_ member: Member, in group: ExpenseGroup, userID: String?) {
        id = member.id
        name = member.name
        groupName = group.name
        isMe = userID != nil && member.userID == userID
    }
}

struct MemberQuery: EntityStringQuery {
    /// When adding an expense, only offer people from the chosen group.
    @IntentParameterDependency<AddExpenseIntent>(\.$group)
    var addExpense

    @MainActor
    private func candidates() throws -> [MemberEntity] {
        let userID = AccountStore.shared.userID
        var groups = try ExpenseRepository.current.groups()
        if let groupID = addExpense?.group.id { groups = groups.filter { $0.id == groupID } }
        return groups.flatMap { group in group.members.map { MemberEntity($0, in: group, userID: userID) } }
    }

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [MemberEntity] {
        try candidates().filter { identifiers.contains($0.id) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [MemberEntity] {
        let all = try candidates()
        if NameMatcher.isSelfReference(string) { return all.filter(\.isMe) }
        return all.filter { NameMatcher.matches($0.name, spoken: string) }
    }

    @MainActor
    func suggestedEntities() async throws -> [MemberEntity] {
        try candidates()
    }
}

/// Loose, case- and accent-insensitive name matching for spoken input.
enum NameMatcher {
    static func matches(_ name: String, spoken: String) -> Bool {
        let name = normalize(name), spoken = normalize(spoken)
        guard !spoken.isEmpty else { return false }
        if name == spoken || name.hasPrefix(spoken) || spoken.hasPrefix(name) { return true }
        // "Maya" should match "Maya Patel", and "the Lisbon trip" should match "Lisbon Trip".
        let nameWords = Set(name.split(separator: " ")), spokenWords = Set(spoken.split(separator: " "))
        return !nameWords.isDisjoint(with: spokenWords.subtracting(["the", "a", "my", "group", "trip"]))
            || name.contains(spoken)
    }

    static func isSelfReference(_ spoken: String) -> Bool {
        ["me", "myself", "i", "mine"].contains(normalize(spoken))
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }
}

nonisolated extension SplitType: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Split"
    static let caseDisplayRepresentations: [SplitType: DisplayRepresentation] = [
        .equal: "Equally",
        .custom: "Custom amounts",
    ]
}

extension ExpenseRepository {
    /// The same store the UI uses, so Siri's writes appear immediately.
    static var current: ExpenseRepository {
        let persistence = PersistenceController.current
        return ExpenseRepository(context: persistence.container.viewContext, persistence: persistence)
    }
}

/// An error whose message Siri reads aloud.
struct SpokenError: Error, CustomLocalizedStringResourceConvertible {
    let localizedStringResource: LocalizedStringResource

    init(_ message: String) {
        localizedStringResource = "\(message)"
    }
}
