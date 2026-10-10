//
//  GroupListView.swift
//  SplitWiseClone
//
import CoreData
import SwiftUI

struct GroupListView: View {
    @EnvironmentObject private var viewModel: GroupListViewModel
    @State private var isPresentingNewGroup = false
    @State private var path: [UUID] = []
    @Namespace private var zoom

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(spacing: 14) {
                    if !viewModel.hasLoaded {
                        ForEach(0..<4, id: \.self) { _ in SkeletonCard() }
                            .transition(.opacity)
                    } else if viewModel.groups.isEmpty {
                        EmptyGroupsView { isPresentingNewGroup = true }
                            .staggeredAppear(0)
                    } else {
                        ForEach(Array(viewModel.groups.enumerated()), id: \.element.id) { index, group in
                            Button {
                                path.append(group.id)
                            } label: {
                                GroupCard(group: group)
                            }
                            .buttonStyle(PressableStyle())
                            .matchedTransitionSource(id: group.id, in: zoom)
                            .contextMenu {
                                Button("Delete Group", systemImage: "trash", role: .destructive) {
                                    viewModel.deleteGroup(group)
                                }
                            }
                            .staggeredAppear(index)
                            .lazyReveal()
                            .transition(.asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity),
                                                    removal: .scale(scale: 0.3).combined(with: .opacity)))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: viewModel.groups.map(\.id))
            .animation(.easeInOut(duration: 0.35), value: viewModel.hasLoaded)
            .background { AppBackground() }
            .navigationTitle("SettleUp")
            .navigationDestination(for: UUID.self) { id in
                GroupDetailView(viewModel: GroupDetailViewModel(groupID: id, context: viewModel.context))
                    .navigationTransition(.zoom(sourceID: id, in: zoom))
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
            .errorAlert($viewModel.errorMessage)
        }
    }
}

private struct GroupCard: View {
    let group: ExpenseGroup

    var body: some View {
        HStack(spacing: 14) {
            Text(group.name.prefix(1).uppercased())
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.stable(for: group.name).gradient))
                .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
            VStack(alignment: .leading, spacing: 8) {
                Text(group.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                AvatarStack(members: group.members, size: 22)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(group.totalSpent, format: .currency(code: "USD"))
                    .font(.system(.headline, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text("\(group.expenses.count) expenses")
                    .font(.caption)
                    .foregroundStyle(Color.subtext)
            }
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(Color.subtext)
        }
        .glassCard()
        .accessibilityElement(children: .combine)
    }
}

private struct EmptyGroupsView: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 60))
                .foregroundStyle(.white)
                .symbolEffect(.wiggle, options: .repeat(.periodic(delay: 2.5)), isActive: !reduceContinuousMotion)
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

/// Spotify's pill: green fill, black bold label.
struct BrandButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black)
            .padding(.horizontal, 28).padding(.vertical, 14)
            .background(Capsule().fill(Color.brand))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .brightness(configuration.isPressed ? 0.08 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    GroupListView()
        .environmentObject(GroupListViewModel(context: PersistenceController.preview.container.viewContext))
        .preferredColorScheme(.dark)
}

