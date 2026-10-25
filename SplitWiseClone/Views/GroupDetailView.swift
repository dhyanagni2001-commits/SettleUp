//
//  GroupDetailView.swift
//  SplitWiseClone
//

import CoreData
import SwiftUI

struct GroupDetailView: View {
    @StateObject var viewModel: GroupDetailViewModel
    @EnvironmentObject private var router: AppRouter
    @State private var expenseSheet: ExpenseSheet?
    @State private var settledCount = 0
    @State private var isAddingPerson = false
    @State private var newPersonName = ""
    @State private var isPreparingInvite = false

    private let spring = Animation.smooth(duration: 0.4)

    private enum ExpenseSheet: Identifiable {
        case new, edit(Expense), draft(ExpenseDraft)

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let expense): expense.id.uuidString
            case .draft(let draft): draft.id.uuidString
            }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                SummaryCard(group: viewModel.group, me: viewModel.me)
                    .staggeredAppear(0)

                if viewModel.me == nil, viewModel.userID != nil, !viewModel.group.members.isEmpty {
                    WhoAreYouCard(members: viewModel.group.members) { member in
                        withAnimation(spring) { viewModel.claim(member) }
                    }
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                    .staggeredAppear(1)
                }

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
                            BalanceRow(balance: balance, maxAbs: maxAbs, index: index, isMe: balance.member.id == viewModel.me?.id,
                                       currency: viewModel.group.primaryCurrency)
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
                    Button {
                        expenseSheet = .edit(expense)
                    } label: {
                        ExpenseRow(expense: expense, meID: viewModel.me?.id)
                            .glassCard(cornerRadius: 16)
                    }
                    .buttonStyle(PressableStyle())
                        .contextMenu {
                            Button("Edit Expense", systemImage: "pencil") { expenseSheet = .edit(expense) }
                            Button("Delete Expense", systemImage: "trash", role: .destructive) {
                                withAnimation(spring) { viewModel.deleteExpense(expense) }
                            }
                        }
                        .staggeredAppear(6 + min(index, 6))
                        .lazyReveal()
                        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                                removal: .scale(scale: 0.8).combined(with: .opacity)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 90)
        }
        .animation(spring, value: viewModel.group.expenses.map(\.id))
        .animation(spring, value: viewModel.settlements.map(\.pairKey))
        .animation(spring, value: viewModel.me)
        .background { AppBackground(tint: Color.stable(for: viewModel.group.name)) }
        .overlay { ConfettiBurst(trigger: settledCount) }
        .sensoryFeedback(.success, trigger: settledCount)
        .navigationTitle(viewModel.group.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            AddExpenseButton { expenseSheet = .new }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if PersistenceController.current.supportsSharing {
                        Button("Invite People", systemImage: "person.crop.circle.badge.plus", action: invite)
                    }
                    Button("Add Person", systemImage: "person.badge.plus") { isAddingPerson = true }
                    if viewModel.me != nil {
                        Menu("Change Who You Are", systemImage: "person.crop.circle") {
                            ForEach(viewModel.group.members) { member in
                                Button(member.name) { withAnimation(spring) { viewModel.claim(member) } }
                            }
                        }
                    }
                } label: {
                    if isPreparingInvite {
                        ProgressView()
                    } else {
                        Label("Group Options", systemImage: "person.2.badge.gearshape")
                    }
                }
            }
        }
        .sheet(item: $expenseSheet) { sheet in
            switch sheet {
            case .new:
                AddExpenseView(group: viewModel.group, defaultPayer: viewModel.me, onSave: save)
            case .edit(let expense):
                AddExpenseView(group: viewModel.group, existing: expense, onSave: save)
            case .draft(let draft):
                AddExpenseView(group: viewModel.group, draft: draft, defaultPayer: viewModel.me, onSave: save)
            }
        }
        .alert("Add Person", isPresented: $isAddingPerson) {
            TextField("Name", text: $newPersonName)
            Button("Cancel", role: .cancel) { newPersonName = "" }
            Button("Add") {
                withAnimation(spring) { viewModel.addMember(named: newPersonName) }
                newPersonName = ""
            }
        }
        .onChange(of: router.draft, initial: true) { _, draft in
            guard let draft, draft.groupID == viewModel.group.id else { return }
            router.draft = nil
            expenseSheet = .draft(draft)
        }
        .errorAlert($viewModel.errorMessage)
    }
}

extension GroupDetailView {
    private func save(_ expense: Expense) {
        withAnimation(spring) { viewModel.saveExpense(expense) }
    }

    private func invite() {
        isPreparingInvite = true
        Task {
            defer { isPreparingInvite = false }
            do {
                try await CloudSharing.presentInvite(for: viewModel.group.id)
            } catch {
                viewModel.errorMessage = "Couldn't create an invitation. Check that you're signed in to iCloud. (\(error.localizedDescription))"
            }
        }
    }
}

/// Asks which member is the signed-in person, so "you owe" and Siri's "me" work.
private struct WhoAreYouCard: View {
    let members: [Member]
    let onPick: (Member) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Which one is you?", systemImage: "person.crop.circle.badge.questionmark")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Pick yourself so SettleUp and Siri can show what you owe.")
                .font(.subheadline)
                .foregroundStyle(Color.subtext)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(members) { member in
                        Button {
                            onPick(member)
                        } label: {
                            HStack(spacing: 6) {
                                Avatar(name: member.name, size: 24)
                                Text(member.name).font(.subheadline.weight(.medium)).foregroundStyle(.white)
                            }
                            .padding(.leading, 4).padding(.trailing, 12).padding(.vertical, 4)
                            .background(Capsule().fill(Color.elevated))
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("This is me: \(member.name)")
                    }
                }
            }
        }
        .glassCard(cornerRadius: 16)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.brand.opacity(0.4), lineWidth: 1))
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
    let me: Member?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(group.name.prefix(1).uppercased())
                .font(.system(size: 60, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 128, height: 128)
                .background(
                    LinearGradient(colors: [Color.stable(for: group.name), Color.stable(for: group.name).opacity(0.6)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                )
                .shadow(color: .black.opacity(0.4), radius: 18, y: 10)
                .frame(maxWidth: .infinity)
            Text("TOTAL SPENT")
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(Color.subtext)
            Text(group.totalSpent, format: .currency(code: group.primaryCurrency))
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.snappy, value: group.totalSpent)
            HStack(spacing: 8) {
                AvatarStack(members: group.members, size: 22)
                Text("\(group.members.count) people · \(group.expenses.count) expenses")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.subtext)
                    .contentTransition(.numericText())
                Spacer()
                if let me {
                    MyBalanceLabel(amount: group.balance(of: me), currency: group.primaryCurrency)
                }
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
    var isMe = false
    var currency = "USD"
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
                    if isMe {
                        Text("You")
                            .font(.caption2.bold())
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.brand))
                    }
                    Spacer()
                    Text(balance.amount, format: .currency(code: currency).sign(strategy: .always(showZero: false)))
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
                            .scaleEffect(x: appeared ? max(fraction, 0.001) : 0.001, anchor: .leading)
                    }
            }
        }
        .animation(.smooth(duration: 0.6), value: fraction)
        .animation(.smooth(duration: 0.8).delay(0.2 + Double(index) * 0.08), value: appeared)
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
    var meID: UUID?

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(category: expense.category, size: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(expense.title).font(.headline).foregroundStyle(.white)
                Text("\(expense.paidBy.id == meID ? "You" : expense.paidBy.name) paid · \(expense.date, format: .dateTime.month().day())")
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
    .environmentObject(AppRouter())
    .preferredColorScheme(.dark)
}
