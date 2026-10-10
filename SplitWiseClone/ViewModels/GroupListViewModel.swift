//
//  GroupListViewModel.swift
//  SplitWiseClone
//
//  Loads and publishes the list of expense groups. Re-fetches whenever the
//  view context saves or CloudKit syncs remote changes down to the local store.
//

import Combine
import CoreData
import Foundation

@MainActor
final class GroupListViewModel: ObservableObject {
    @Published private(set) var groups: [ExpenseGroup] = []
    @Published var errorMessage: String?
    /// False until the first fetch lands; drives the skeleton placeholder.
    @Published private(set) var hasLoaded = false

    let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()

    init(context: NSManagedObjectContext) {
        self.context = context
        Publishers.Merge(
            NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange),
            NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: context)
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in self?.loadGroups() }
        .store(in: &cancellables)

        // Short beat on cold start so the skeleton → content handoff animates
        // instead of flashing (and covers the CloudKit store warming up).
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            loadGroups()
            hasLoaded = true
        }
    }

    func loadGroups() {
        let request = CDGroup.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDGroup.createdAt, ascending: false)]
        do {
            groups = try context.fetch(request).map(\.domain)
        } catch {
            errorMessage = "Couldn't load groups: \(error.localizedDescription)"
        }
    }

    func addGroup(name: String, memberNames: [String]) {
        let cdGroup = CDGroup(context: context)
        cdGroup.id = UUID()
        cdGroup.name = name
        cdGroup.createdAt = Date()

        for memberName in memberNames {
            let cdMember = CDMember(context: context)
            cdMember.id = UUID()
            cdMember.name = memberName
            cdMember.group = cdGroup
        }
        save("create group")
    }

    func deleteGroup(_ group: ExpenseGroup) {
        guard let cdGroup = try? context.fetchOne(CDGroup.self, id: group.id) else { return }
        context.delete(cdGroup)
        save("delete group")
    }

    private func save(_ action: String) {
        do {
            try context.save()
        } catch {
            context.rollback()
            errorMessage = "Couldn't \(action): \(error.localizedDescription)"
        }
    }
}
