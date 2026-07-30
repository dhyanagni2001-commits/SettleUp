//
//  GroupListViewModel.swift
//  SplitWiseClone
//
//  Loads and publishes the list of expense groups. Uses a Combine
//  publisher over an NSFetchRequest so the list stays live as
//  CloudKit syncs remote changes down to the local store.
//

import Combine
import CoreData
import Foundation

@MainActor
final class GroupListViewModel: ObservableObject {
    @Published private(set) var groups: [ExpenseGroup] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()

    init(context: NSManagedObjectContext) {
        self.context = context
        observeRemoteChanges()
        loadGroups()
    }

    /// Re-fetch whenever Core Data reports a remote (CloudKit) change,
    /// so groups edited on another device show up here automatically.
    private func observeRemoteChanges() {
        NotificationCenter.default
            .publisher(for: .NSPersistentStoreRemoteChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadGroups()
            }
            .store(in: &cancellables)
    }

    func loadGroups() {
        isLoading = true
        defer { isLoading = false }

        // TODO: replace with a real NSFetchRequest<CDGroup> once the
        // Core Data model + generated classes exist, then map each
        // CDGroup -> ExpenseGroup. Left as a fetch-and-map function so
        // the mapping logic (and this ViewModel's tests) don't depend
        // on the store being populated.
        do {
            groups = try fetchGroups(in: context)
        } catch {
            errorMessage = "Couldn't load groups: \(error.localizedDescription)"
        }
    }

    func addGroup(name: String, memberNames: [String]) {
        // TODO: create CDGroup + CDMember managed objects, save context,
        // then call loadGroups() (or rely on the save notification).
    }

    private func fetchGroups(in context: NSManagedObjectContext) throws -> [ExpenseGroup] {
        // Placeholder until Core Data entities exist — returns an empty
        // list rather than throwing, so previews/tests don't crash.
        return []
    }
}
