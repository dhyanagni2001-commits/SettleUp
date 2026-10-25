//
//  CloudSharing.swift
//  SplitWiseClone
//
//  Invites other iCloud users to a group with the system sharing sheet.
//  Presented from UIKit directly: UICloudSharingController misbehaves when
//  wrapped in a SwiftUI sheet.
//

import CloudKit
import CoreData
import UIKit

enum CloudSharing {
    @MainActor
    static func presentInvite(for groupID: UUID) async throws {
        let persistence = PersistenceController.current
        let context = persistence.container.viewContext
        guard let group = try context.fetchOne(CDGroup.self, id: groupID) else { throw RepositoryError.groupNotFound }

        let share = try await persistence.share(group)
        let controller = UICloudSharingController(share: share, container: persistence.cloudKitContainer)
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        controller.modalPresentationStyle = .formSheet
        topViewController()?.present(controller, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
