//
//  NewGroupView.swift
//  SplitWiseClone
//

import SwiftUI

struct NewGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var groupName = ""
    @State private var newMember = ""
    @State private var members: [String] = []
    @FocusState private var memberFieldFocused: Bool

    let onCreate: (_ name: String, _ memberNames: [String]) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Group") {
                    TextField("Group name", text: $groupName)
                }
                Section {
                    ForEach(members, id: \.self) { name in
                        HStack(spacing: 12) {
                            Avatar(name: name, size: 30)
                            Text(name)
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    .onDelete { members.remove(atOffsets: $0) }

                    HStack {
                        TextField("Add member", text: $newMember)
                            .focused($memberFieldFocused)
                            .submitLabel(.next)
                            .onSubmit(addMember)
                        Button(action: addMember) {
                            Image(systemName: "plus.circle.fill").font(.title2)
                        }
                        .disabled(trimmed(newMember).isEmpty)
                        .accessibilityLabel("Add member")
                    }
                } header: {
                    Text("Members (\(members.count))")
                        .contentTransition(.numericText())
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: members)
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        addMember()
                        onCreate(trimmed(groupName), members)
                        dismiss()
                    }
                    .disabled(trimmed(groupName).isEmpty || (members.isEmpty && trimmed(newMember).isEmpty))
                }
            }
        }
    }

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespaces)
    }

    private func addMember() {
        let name = trimmed(newMember)
        guard !name.isEmpty, !members.contains(name) else { return }
        members.append(name)
        newMember = ""
        memberFieldFocused = true
    }
}

#Preview {
    NewGroupView(onCreate: { _, _ in })
}
