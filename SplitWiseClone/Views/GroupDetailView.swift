//
//  GroupDetailView.swift
//  SplitWiseClone
//

import CoreData
import SwiftUI

struct GroupDetailView: View {
    @StateObject var viewModel: GroupDetailViewModel
    @State private var isPresentingAddExpense = false
    @State private var settledCount = 0

    private let spring = Animation.spring(response: 0.5, dampingFraction: 0.72)

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                SummaryCard(group: viewModel.group)
                    .staggeredAppear(0)

                SectionTitle(title: "Settle Up", symbol: "arrow.left.arrow.right")
                    .staggeredAppear(1)
                VStack(spacing: 0) {
                    if viewModel.settlements.isEmpty {
                        AllSettledView(trigger: settledCount, hasExpenses: !viewModel.group.expenses.isEmpty)
                    } else {
                        ForEach(Array(viewModel.settlements.enumerated()), id: \.element.pairKey) { index, settlement in
                            if index > 0 { Divider().overlay(.white.opacity(0.15)).padding(.vertical, 10) }
                            SettlementRow(settlement: settlement) {
                                withAnimation(spring) { viewModel.markSettled(settlement) }
                                settledCount += 1
                            }
                            .transition(.asymmetric(
                                insertion: .opacity,
                                removal: .offset(x: 300).combined(with: .opacity).combined(with: .scale(scale: 0.6))
                            ))
                        }
                    }
                }
                .glassCard()
                .staggeredAppear(2)

                if !viewModel.balances.isEmpty {
                    SectionTitle(title: "Balances", symbol: "chart.bar.fill")
                        .staggeredAppear(3)
                    VStack(spacing: 16) {
                        let maxAbs = viewModel.balances.map { abs($0.amount) }.max() ?? 0
                        ForEach(Array(viewModel.balances.enumerated()), id: \.element.id) { index, balance in
                            BalanceRow(balance: balance, maxAbs: maxAbs, index: index)
                        }
                    }
                    .glassCard()
                    .staggeredAppear(4)
                }

                SectionTitle(title: "Expenses", symbol: "list.bullet.rectangle.fill")
                    .staggeredAppear(5)
                if viewModel.group.expenses.isEmpty {
                    Text("No expenses yet. Tap Add Expense to start.")
                        .foregroundStyle(Color.subtext)
                        .glassCard()
                        .staggeredAppear(6)
                }
                ForEach(Array(viewModel.group.expenses.enumerated()), id: \.element.id) { index, expense in
                    ExpenseRow(expense: expense)
                        .glassCard(cornerRadius: 20)
                        .contextMenu {
                            Button("Delete Expense", systemImage: "trash", role: .destructive) {
                                withAnimation(spring) { viewModel.deleteExpense(expense) }
                            }
                        }
                        .staggeredAppear(6 + min(index, 6))
                        .lazyReveal()
                        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.8)),
                                                removal: .scale(scale: 0.5).combined(with: .opacity)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 90)
        }
        .animation(spring, value: viewModel.group.expenses.map(\.id))
        .animation(spring, value: viewModel.settlements.map(\.pairKey))
        .background { AppBackground(tint: Color.stable(for: viewModel.group.name)) }
        .overlay { ConfettiBurst(trigger: settledCount) }
        .sensoryFeedback(.success, trigger: settledCount)
        .navigationTitle(viewModel.group.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            AddExpenseButton { isPresentingAddExpense = true }
        }
        .sheet(isPresented: $isPresentingAddExpense) {
            AddExpenseView(group: viewModel.group) { expense in
                withAnimation(spring) { viewModel.addExpense(expense) }
            }
        }
        .errorAlert($viewModel.errorMessage)
    }
}

private struct AddExpenseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Add Expense", systemImage: "plus")
                .phaseAnimator(reduceContinuousMotion ? [false] : [false, true]) { content, glowing in
                    content.shadow(color: .brand.opacity(glowing ? 0.6 : 0.15), radius: glowing ? 18 : 6, y: 4)
                } animation: { _ in .easeInOut(duration: 1.4) }
        }
        .buttonStyle(BrandButtonStyle())
        .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
        .padding(.bottom, 8)
    }
}

/// Playlist-style header: cover tile, eyebrow, huge bold total.
private struct SummaryCard: View {
    let group: ExpenseGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(group.name.prefix(1).uppercased())
                .font(.system(size: 72, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 150, height: 150)
                .background(
                    LinearGradient(colors: [Color.stable(for: group.name), Color.stable(for: group.name).opacity(0.55)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .shadow(color: .black.opacity(0.6), radius: 24, y: 12)
                .frame(maxWidth: .infinity)
            Text("TOTAL SPENT")
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(Color.subtext)
            Text(group.totalSpent, format: .currency(code: "USD"))
                .font(.system(size: 44, weight: .black))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.snappy, value: group.totalSpent)
            HStack(spacing: 8) {
                AvatarStack(members: group.members, size: 22)
                Text("\(group.members.count) people · \(group.expenses.count) expenses")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.subtext)
                    .contentTransition(.numericText())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}

private struct BalanceRow: View {
    let balance: MemberBalance
    let maxAbs: Decimal
    let index: Int
    @State private var appeared = false

    private var fraction: CGFloat {
        guard maxAbs > 0 else { return 0 }
        return CGFloat(truncating: (abs(balance.amount) / maxAbs) as NSDecimalNumber)
    }

    private var color: Color { balance.amount > 0 ? .brand : balance.amount < 0 ? .negative : .subtext }

    var body: some View {
        HStack(spacing: 12) {
            Avatar(name: balance.member.name)
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(balance.member.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Spacer()
                    Text(balance.amount, format: .currency(code: "USD").sign(strategy: .always(showZero: false)))
                        .font(.system(.subheadline, design: .rounded).monospacedDigit().weight(.bold))
                        .foregroundStyle(color)
                        .contentTransition(.numericText())
                }
                Capsule()
                    .fill(Color.elevated)
                    .frame(height: 8)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(LinearGradient(colors: [color.opacity(0.6), color], startPoint: .leading, endPoint: .trailing))
                            .shadow(color: color.opacity(0.8), radius: 6)
                            .scaleEffect(x: appeared ? max(fraction, 0.001) : 0.001, anchor: .leading)
                    }
            }
        }
        .animation(.spring(response: 0.8, dampingFraction: 0.65), value: fraction)
        .animation(.spring(response: 0.9, dampingFraction: 0.65).delay(0.3 + Double(index) * 0.1), value: appeared)
        .onAppear { appeared = true }
    }
}

private struct SettlementRow: View {
    let settlement: Settlement
    let onMarkSettled: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Avatar(name: settlement.from.name)
            Image(systemName: "arrow.right")
                .font(.caption.bold())
                .foregroundStyle(Color.subtext)
                .symbolEffect(.wiggle.right, options: .repeat(.periodic(delay: 2)), isActive: !reduceContinuousMotion)
            Avatar(name: settlement.to.name)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(settlement.from.name) pays \(settlement.to.name)")
                    .font(.subheadline)
                    .foregroundStyle(Color.subtext)
                    .lineLimit(1)
                Text(settlement.amount, format: .currency(code: settlement.currencyCode))
                    .font(.system(.headline, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            Spacer()
            Button(action: onMarkSettled) {
                Text("Settle").font(.subheadline.bold()).foregroundStyle(.black)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.brand)
        }
    }
}

private struct AllSettledView: View {
    let trigger: Int
    let hasExpenses: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.brand)
                .symbolEffect(.bounce.up.byLayer, value: trigger)
                .shadow(color: .brand.opacity(0.5), radius: 10)
            VStack(alignment: .leading) {
                Text("All settled up").font(.headline).foregroundStyle(.white)
                Text(hasExpenses ? "Nobody owes anybody 🎉" : "Add an expense to get started.")
                    .font(.subheadline)
                    .foregroundStyle(Color.subtext)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.scale(scale: 0.5).combined(with: .opacity))
    }
}

private struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(category: expense.category, size: 42)
                .shadow(color: expense.category.tint.opacity(0.6), radius: 8)
            VStack(alignment: .leading, spacing: 3) {
                Text(expense.title).font(.headline).foregroundStyle(.white)
                Text("\(expense.paidBy.name) paid · \(expense.date, format: .dateTime.month().day())")
                    .font(.caption)
                    .foregroundStyle(Color.subtext)
            }
            Spacer()
            Text(expense.amount, format: .currency(code: expense.currencyCode))
                .font(.system(.subheadline, design: .rounded).monospacedDigit().weight(.bold))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let id = (try? context.fetch(CDGroup.fetchRequest()).first?.id) ?? UUID()
    return NavigationStack {
        GroupDetailView(viewModel: GroupDetailViewModel(groupID: id, context: context))
    }
    .preferredColorScheme(.dark)
}
