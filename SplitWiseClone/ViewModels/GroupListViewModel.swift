//
//  GroupListViewModel.swift
//  SplitWiseClone
//
//  Loads and publishes the list of expense groups. Re-fetches whenever the
//  view context saves or CloudKit syncs remote changes down to the local store.
//

import AppIntents
import Combine
import CoreData
import Foundation

@MainActor
final class GroupListViewModel: ObservableObject {
    @Published private(set) var groups: [ExpenseGroup] = []
    @Published var errorMessage: String?
    /// False until the first fetch lands; drives the skeleton placeholder.
    @Published private(set) var hasLoaded = false

    let repository: ExpenseRepository
    var context: NSManagedObjectContext { repository.context }
    private var cancellables = Set<AnyCancellable>()

    init(repository: ExpenseRepository) {
        self.repository = repository
        Publishers.Merge(
            NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange),
            NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: repository.context)
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in self?.loadGroups() }
        .store(in: &cancellables)

        // Short beat on cold start so the skeleton → content handoff animates
        // instead of flashing (and covers the CloudKit store warming up).
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            loadGroups()
            hasLoaded = true
        }
    }

    convenience init(context: NSManagedObjectContext) {
        self.init(repository: ExpenseRepository(context: context))
    }

    func loadGroups() {
        do {
            let fresh = try repository.groups()
            // Siri learns group names from here, so refresh them when they change.
            if fresh.map(\.name) != groups.map(\.name) { SettleUpShortcuts.updateAppShortcutParameters() }
            groups = fresh
        } catch {
            errorMessage = "Couldn't load groups: \(error.localizedDescription)"
        }
    }

    func addGroup(name: String, memberNames: [String], me: (name: String, userID: String)?) {
        perform("create group") { try repository.createGroup(name: name, memberNames: memberNames, me: me) }
    }

    func deleteGroup(_ group: ExpenseGroup) {
        perform("delete group") { try repository.deleteGroup(id: group.id) }
    }

    func relinkUser(from oldID: String, to newID: String) throws {
        try repository.relinkUser(from: oldID, to: newID)
    }

    func deleteAllData(for userID: String?) {
        perform("delete your data") { try repository.deleteAllData(for: userID) }
    }

    private func perform(_ action: String, _ work: () throws -> Void) {
        do {
            try work()
        } catch {
            errorMessage = "Couldn't \(action): \(error.localizedDescription)"
        }
    }
}
