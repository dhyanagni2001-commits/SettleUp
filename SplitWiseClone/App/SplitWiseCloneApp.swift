//
//  SplitWiseCloneApp.swift
//  SplitWiseClone
//
//  App entry point. Wires up the Core Data + CloudKit persistence stack,
//  the signed-in account, and the router App Intents use to open screens.
//
import CloudKit
import CoreData
import SwiftUI
import UIKit

@main
struct SplitWiseCloneApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

    let persistenceController = PersistenceController.current

    @StateObject private var groupList: GroupListViewModel
    @StateObject private var account = AccountStore.shared
    @StateObject private var router = AppRouter.shared

    init() {
        let persistence = PersistenceController.current
        _groupList = StateObject(wrappedValue: GroupListViewModel(
            repository: ExpenseRepository(context: persistence.container.viewContext, persistence: persistence)
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(groupList)
                .environmentObject(account)
                .environmentObject(router)
                .preferredColorScheme(.dark)
                .tint(.brand)
        }
    }
}

/// Root switch between onboarding and the app, cross-fading between them.
struct RootView: View {
    @EnvironmentObject private var account: AccountStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if !account.isSignedIn {
                WelcomeView()
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
            } else if account.needsProfileSetup {
                ProfileSetupView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                GroupListView()
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.smooth(duration: 0.45), value: account.isSignedIn)
        .animation(.smooth(duration: 0.45), value: account.needsProfileSetup)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await account.verifyAppleCredential() } }
        }
    }
}

/// Accepting a CloudKit share arrives through the scene delegate, which a
/// SwiftUI app only gets by vending its own scene configuration.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        PersistenceController.current.acceptShare(cloudKitShareMetadata)
    }
}
