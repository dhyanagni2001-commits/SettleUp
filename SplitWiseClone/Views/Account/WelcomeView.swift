//
//  WelcomeView.swift
//  SplitWiseClone
//
//  First-launch screen: app name, one line of pitch, Sign in with Apple,
//  and an optional guest path. No email/password form on purpose.
//

import AuthenticationServices
import CoreData
import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var account: AccountStore
    @EnvironmentObject private var groupList: GroupListViewModel
    @State private var appeared = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            FloatingExpenses()
                .frame(height: 200)
                .opacity(appeared ? 1 : 0)
                .animation(.smooth(duration: 0.8).delay(0.35), value: appeared)

            VStack(spacing: 14) {
                AppMark()
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: appeared)

                Text("SettleUp")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .rise(appeared, delay: 0.1)

                Text("Shared expenses, settled simply.")
                    .font(.title3)
                    .foregroundStyle(Color.subtext)
                    .rise(appeared, delay: 0.18)
            }
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 14) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    signIn(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 54)
                .clipShape(Capsule())
                .rise(appeared, delay: 0.26)

                Button("Continue as Guest") { account.continueAsGuest() }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                    .contentShape(Capsule())
                    .buttonStyle(PressableStyle())
                    .rise(appeared, delay: 0.32)

                Text("Guests keep their groups when they sign in later.")
                    .font(.footnote)
                    .foregroundStyle(Color.subtext)
                    .rise(appeared, delay: 0.38)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
        .background { AppBackground() }
        .onAppear { appeared = true }
        .errorAlert($errorMessage)
    }

    private func signIn(_ result: Result<ASAuthorization, Error>) {
        do {
            try account.completeAppleSignIn(result, relink: groupList.relinkUser)
        } catch let error as ASAuthorizationError where error.code == .canceled {
            // The person closed the sheet; nothing to report.
        } catch {
            errorMessage = "Sign in didn't complete: \(error.localizedDescription)"
        }
    }
}

/// Green tile with the "two people settling" glyph.
struct AppMark: View {
    var size: CGFloat = 84

    var body: some View {
        Image(systemName: "arrow.left.arrow.right")
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(.black)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous).fill(Color.brand.gradient))
            .shadow(color: .brand.opacity(0.35), radius: 24, y: 8)
    }
}

/// A few example expense chips drifting slowly, to hint at what the app does.
private struct FloatingExpenses: View {
    private let items: [(String, String, CGPoint)] = [
        ("fork.knife", "Dinner · $84", CGPoint(x: 0.28, y: 0.25)),
        ("car.fill", "Taxi · $23", CGPoint(x: 0.72, y: 0.45)),
        ("bed.double.fill", "Hotel · $410", CGPoint(x: 0.34, y: 0.78)),
    ]

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(paused: reduceContinuousMotion)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                // ZStack so every chip is positioned in the same space, not stacked.
                ZStack {
                ForEach(items.indices, id: \.self) { index in
                    let (symbol, label, anchor) = items[index]
                    Label(label, systemImage: symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(Capsule().fill(Color.elevated))
                        .overlay(Capsule().stroke(Color.white.opacity(0.08)))
                        .position(x: anchor.x * proxy.size.width,
                                  y: anchor.y * proxy.size.height + sin(t * 0.9 + Double(index) * 2) * 6)
                }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .accessibilityHidden(true)
    }
}

extension View {
    /// Fades in and rises a little; used for onboarding entrance choreography.
    func rise(_ visible: Bool, delay: Double) -> some View {
        opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 14)
            .animation(.smooth(duration: 0.6).delay(delay), value: visible)
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AccountStore())
        .environmentObject(GroupListViewModel(context: PersistenceController.preview.container.viewContext))
        .preferredColorScheme(.dark)
}
