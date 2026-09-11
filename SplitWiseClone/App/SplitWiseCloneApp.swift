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
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            GroupListView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(GroupListViewModel(context: persistenceController.container.viewContext))
        }
    }
}
