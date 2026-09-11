//
//  GroupListView.swift
//  SplitWiseClone
//
import CoreData
import SwiftUI

struct GroupListView: View {
    @EnvironmentObject private var viewModel: GroupListViewModel
    @State private var isPresentingNewGroup = false

    var body: some View {
        NavigationStack {
            List {
                if viewModel.groups.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "No Groups Yet",
                        systemImage: "person.3",
                        description: Text("Create a group to start splitting expenses.")
                    )
                }
                ForEach(viewModel.groups) { group in
                    NavigationLink(value: group) {
                        VStack(alignment: .leading) {
                            Text(group.name).font(.headline)
                            Text("\(group.members.count) members")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Groups")
            .navigationDestination(for: ExpenseGroup.self) { group in
                GroupDetailView(viewModel: GroupDetailViewModel(group: group, context: viewModel.context))
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingNewGroup = true
                    } label: {
                        Label("New Group", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingNewGroup) {
                NewGroupView { name, members in
                    viewModel.addGroup(name: name, memberNames: members)
                }
            }
            .alert(
                "Error",
                isPresented: .constant(viewModel.errorMessage != nil),
                actions: { Button("OK") { viewModel.errorMessage = nil } },
                message: { Text(viewModel.errorMessage ?? "") }
            )
        }
    }
}

#Preview {
    GroupListView()
        .environmentObject(GroupListViewModel(context: PersistenceController.preview.container.viewContext))
}
