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

    /// The signed-in person, always added to new groups and linked to their account.
    let meName: String
    let onCreate: (_ name: String, _ memberNames: [String]) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Group") {
                    TextField("Group name", text: $groupName)
                }
                Section {
                    if !meName.isEmpty {
                        HStack(spacing: 12) {
                            Avatar(name: meName, size: 30)
                            Text(meName)
                            Spacer()
                            Text("You").font(.caption.bold()).foregroundStyle(Color.subtext)
                        }
                    }
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
                    Text("Members (\(members.count + (meName.isEmpty ? 0 : 1)))")
                        .contentTransition(.numericText())
                }
            }
            .animation(.smooth(duration: 0.3), value: members)
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
                    .disabled(trimmed(groupName).isEmpty || (members.isEmpty && trimmed(newMember).isEmpty && meName.isEmpty))
                }
            }
        }
    }

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespaces)
    }

    private func addMember() {
        let name = trimmed(newMember)
        guard !name.isEmpty, !members.contains(name), name != meName else { return }
        members.append(name)
        newMember = ""
        memberFieldFocused = true
    }
}

#Preview {
    NewGroupView(meName: "Dhyan", onCreate: { _, _ in })
}
