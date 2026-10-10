//
//  SplitWiseCloneApp.swift
//  SplitWiseClone
//
//  App entry point. Wires up the Core Data + CloudKit persistence stack
//  and injects the managed object context into the SwiftUI environment.
//
import CoreData
import SwiftUI

@main
struct SplitWiseCloneApp: App {
    // UI tests launch with -uiTesting for a clean in-memory store;
    // -demoData launches with the seeded in-memory preview store.
    let persistenceController: PersistenceController = {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTesting") { return PersistenceController(inMemory: true) }
        if arguments.contains("-demoData") { return .preview }
        return .shared
    }()

    @StateObject private var groupList: GroupListViewModel

    init() {
        let context = persistenceController.container.viewContext
        _groupList = StateObject(wrappedValue: GroupListViewModel(context: context))
    }

    var body: some Scene {
        WindowGroup {
            GroupListView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(groupList)
                .preferredColorScheme(.dark)
                .tint(.brand)
        }
    }
}
