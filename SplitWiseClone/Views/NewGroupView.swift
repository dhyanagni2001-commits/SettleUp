//
//  NewGroupView.swift
//  SplitWiseClone
//

import SwiftUI

struct NewGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var groupName = ""
    @State private var memberNamesText = ""

    let onCreate: (_ name: String, _ memberNames: [String]) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Group") {
                    TextField("Group name", text: $groupName)
                }
                Section("Members") {
                    TextField("Comma-separated names", text: $memberNamesText, axis: .vertical)
                    Text("e.g. Dhyan, Alex, Priya")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let members = memberNamesText
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        onCreate(groupName, members)
                        dismiss()
                    }
                    .disabled(groupName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    NewGroupView(onCreate: { _, _ in })
}
