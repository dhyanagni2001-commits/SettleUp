//
//  GroupListView.swift
//  SplitWiseClone
//
import CoreData
import SwiftUI

struct GroupListView: View {
    @EnvironmentObject private var viewModel: GroupListViewModel
    @EnvironmentObject private var account: AccountStore
    @EnvironmentObject private var router: AppRouter
    @State private var isPresentingNewGroup = false
    @State private var isPresentingAccount = false
    @State private var path: [UUID] = []
    @Namespace private var zoom

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if !viewModel.hasLoaded {
                        ForEach(0..<4, id: \.self) { _ in SkeletonCard() }
                            .transition(.opacity)
                    } else if viewModel.groups.isEmpty {
                        EmptyGroupsView { isPresentingNewGroup = true }
                            .staggeredAppear(0)
                    } else {
                        if viewModel.groups.contains(where: { $0.me(account.userID) != nil }) {
                            OverallBalanceCard(groups: viewModel.groups, userID: account.userID)
                                .staggeredAppear(0)
                        }
                        ForEach(Array(viewModel.groups.enumerated()), id: \.element.id) { index, group in
                            Button {
                                path.append(group.id)
                            } label: {
                                GroupCard(group: group, me: group.me(account.userID))
                            }
                            .buttonStyle(PressableStyle())
                            .matchedTransitionSource(id: group.id, in: zoom)
                            .contextMenu {
                                Button("Delete Group", systemImage: "trash", role: .destructive) {
                                    viewModel.deleteGroup(group)
                                }
                            }
                            .staggeredAppear(index + 1)
                            .lazyReveal()
                            .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity),
                                                    removal: .scale(scale: 0.8).combined(with: .opacity)))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .animation(.smooth(duration: 0.4), value: viewModel.groups.map(\.id))
            .animation(.smooth(duration: 0.35), value: viewModel.hasLoaded)
            .background { AppBackground() }
            .navigationTitle("SettleUp")
            .navigationDestination(for: UUID.self) { id in
                GroupDetailView(viewModel: GroupDetailViewModel(groupID: id, repository: viewModel.repository, userID: account.userID))
                    .navigationTransition(.zoom(sourceID: id, in: zoom))
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isPresentingAccount = true
                    } label: {
                        ProfileAvatarImage(name: account.profile?.displayName ?? "?", image: account.avatar, size: 30)
                    }
                    .accessibilityLabel("Account")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingNewGroup = true
                    } label: {
                        Label("New Group", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingNewGroup) {
                NewGroupView(meName: account.profile?.displayName ?? "") { name, members in
                    let me = account.profile.map { (name: $0.displayName, userID: $0.userID) }
                    viewModel.addGroup(name: name, memberNames: members, me: me)
                }
            }
            .sheet(isPresented: $isPresentingAccount) {
                AccountView()
            }
            .errorAlert($viewModel.errorMessage)
            .onChange(of: router.openGroupID, initial: true) { _, id in
                guard let id else { return }
                isPresentingAccount = false
                isPresentingNewGroup = false
                path = [id]
                router.openGroupID = nil
            }
        }
    }
}

/// Totals across every group where the person has said which member they are.
private struct OverallBalanceCard: View {
    let groups: [ExpenseGroup]
    let userID: String?

    private var totals: (owed: Decimal, owe: Decimal, currency: String) {
        var owed: Decimal = 0, owe: Decimal = 0
        for group in groups {
            guard let me = group.me(userID) else { continue }
            let balance = group.balance(of: me)
            if balance > 0 { owed += balance } else { owe -= balance }
        }
        return (owed, owe, groups.first?.primaryCurrency ?? "USD")
    }

    var body: some View {
        let totals = totals
        HStack(spacing: 0) {
            tile("You're owed", totals.owed, totals.currency, color: .brand)
            Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 44)
            tile("You owe", totals.owe, totals.currency, color: totals.owe > 0 ? .negative : .white)
        }
        .glassCard(cornerRadius: 16)
    }

    private func tile(_ title: String, _ amount: Decimal, _ currency: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(Color.subtext)
            Text(amount, format: .currency(code: currency))
                .font(.system(.title2, design: .rounded).weight(.bold).monospacedDigit())
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(.smooth, value: amount)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}

private struct GroupCard: View {
    let group: ExpenseGroup
    let me: Member?

    var body: some View {
        HStack(spacing: 14) {
            Text(group.name.prefix(1).uppercased())
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.stable(for: group.name).gradient))
            VStack(alignment: .leading, spacing: 8) {
                Text(group.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                AvatarStack(members: group.members, size: 22)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let me {
                    MyBalanceLabel(amount: group.balance(of: me), currency: group.primaryCurrency)
                } else {
                    Text(group.totalSpent, format: .currency(code: group.primaryCurrency))
                        .font(.system(.headline, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
                Text("\(group.expenses.count) expenses")
                    .font(.caption)
                    .foregroundStyle(Color.subtext)
            }
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(Color.subtext)
        }
        .glassCard(cornerRadius: 16)
        .accessibilityElement(children: .combine)
    }
}

/// "you're owed $40" / "you owe $12" / "settled up".
struct MyBalanceLabel: View {
    let amount: Decimal
    let currency: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(amount > 0 ? "you're owed" : amount < 0 ? "you owe" : "settled up")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.subtext)
            if amount != 0 {
                Text(abs(amount), format: .currency(code: currency))
                    .font(.system(.headline, design: .rounded).monospacedDigit())
                    .foregroundStyle(amount > 0 ? Color.brand : Color.negative)
                    .contentTransition(.numericText())
            }
        }
        .animation(.smooth, value: amount)
    }
}

private struct EmptyGroupsView: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white)
                .symbolEffect(.bounce, options: .repeat(.periodic(delay: 3)), isActive: !reduceContinuousMotion)
            Text("No Groups Yet").font(.title2.bold()).foregroundStyle(.white)
            Text("Create a group to start splitting expenses.")
                .foregroundStyle(Color.subtext)
            Button("New Group", systemImage: "plus", action: onCreate)
                .buttonStyle(BrandButtonStyle())
        }
        .padding(.vertical, 36)
        .glassCard(cornerRadius: 16)
        .padding(.top, 40)
    }
}

/// Pill button: green fill, black bold label.
struct BrandButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black)
            .padding(.horizontal, 28).padding(.vertical, 14)
            .background(Capsule().fill(Color.brand))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? 0.05 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    GroupListView()
        .environmentObject(GroupListViewModel(context: PersistenceController.preview.container.viewContext))
        .environmentObject(AccountStore())
        .environmentObject(AppRouter())
        .preferredColorScheme(.dark)
}
