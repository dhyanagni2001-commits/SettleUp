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

    let context: NSManagedObjectContext
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

        do {
            groups = try fetchGroups(in: context)
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

        do {
            try context.save()
            loadGroups()
        } catch {
            errorMessage = "Couldn't create group: \(error.localizedDescription)"
        }
    }

    private func fetchGroups(in context: NSManagedObjectContext) throws -> [ExpenseGroup] {
        let request = CDGroup.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDGroup.createdAt, ascending: false)]
        let cdGroups = try context.fetch(request)

        return cdGroups.map { cdGroup in
            let members = (cdGroup.members as? Set<CDMember> ?? [])
                .map { Member(id: $0.id ?? UUID(), name: $0.name ?? "") }
                .sorted { $0.name < $1.name }

            return ExpenseGroup(
                id: cdGroup.id ?? UUID(),
                name: cdGroup.name ?? "",
                members: members,
                expenses: [] // expenses mapping comes later, once GroupDetailViewModel needs it
            )
        }
    }
}
