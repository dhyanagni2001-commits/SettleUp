//
//  GroupDetailView.swift
//  SplitWiseClone
//

import SwiftUI

struct GroupDetailView: View {
    @StateObject var viewModel: GroupDetailViewModel
    @State private var isPresentingAddExpense = false

    var body: some View {
        List {
            Section("Expenses") {
                if viewModel.group.expenses.isEmpty {
                    Text("No expenses yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(viewModel.group.expenses) { expense in
                    ExpenseRow(expense: expense)
                }
            }

            Section("Balances") {
                ForEach(Array(viewModel.balances.keys), id: \.self) { member in
                    let balance = viewModel.balances[member] ?? 0
                    HStack {
                        Text(member.name)
                        Spacer()
                        Text(balance, format: .currency(code: "USD"))
                            .foregroundStyle(balance >= 0 ? .green : .red)
                    }
                }
            }

            Section("Settle Up") {
                if viewModel.settlements.isEmpty {
                    Text("Everyone's settled up 🎉")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.settlements) { settlement in
                        SettlementRow(settlement: settlement) {
                            viewModel.markSettled(settlement)
                        }
                    }
                }
            }
        }
        .navigationTitle(viewModel.group.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingAddExpense = true
                } label: {
                    Label("Add Expense", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingAddExpense) {
            AddExpenseView(group: viewModel.group) { expense in
                viewModel.addExpense(expense)
            }
        }
    }
}

private struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(expense.title).font(.headline)
                Text("Paid by \(expense.paidBy.name) · \(expense.category.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(expense.amount, format: .currency(code: expense.currencyCode))
        }
    }
}

private struct SettlementRow: View {
    let settlement: Settlement
    let onMarkSettled: () -> Void

    var body: some View {
        HStack {
            Text("\(settlement.from.name) → \(settlement.to.name)")
            Spacer()
            Text(settlement.amount, format: .currency(code: settlement.currencyCode))
            Button("Settled", action: onMarkSettled)
                .buttonStyle(.bordered)
        }
    }
}
