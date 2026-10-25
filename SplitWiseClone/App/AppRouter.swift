//
//  AppRouter.swift
//  SplitWiseClone
//
//  Lets App Intents steer the UI: open a group, or hand over a partly
//  filled expense for the person to finish in the form.
//

import Combine
import Foundation

@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    @Published var openGroupID: UUID?
    @Published var draft: ExpenseDraft?

    func review(_ draft: ExpenseDraft) {
        self.draft = draft
        openGroupID = draft.groupID
    }
}
