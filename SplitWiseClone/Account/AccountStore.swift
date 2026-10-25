//
//  AccountStore.swift
//  SplitWiseClone
//
//  Who is using the app. Sign in with Apple gives us a stable user
//  identifier (never a password); guests get a random local one. Only the
//  identifier and the profile the app shows are stored. Signing in is
//  separate from sharing: CloudKit shares handle collaboration.
//

import AuthenticationServices
import Combine
import SwiftUI
import UIKit

struct Profile: Codable, Equatable {
    enum Kind: String, Codable { case apple, guest }

    var userID: String
    var kind: Kind
    var displayName: String = ""
    var email: String?
}

@MainActor
final class AccountStore: ObservableObject {
    static let shared = AccountStore()

    @Published private(set) var profile: Profile?
    @Published private(set) var avatar: UIImage?

    var userID: String? { profile?.userID }
    var isSignedIn: Bool { profile != nil }
    var needsProfileSetup: Bool { profile?.displayName.isEmpty ?? false }

    private let defaults: UserDefaults
    private let avatarDirectory: URL
    private let currentKey = "account.currentUserID"
    private let profilesKey = "account.profiles"

    init() {
        // UI tests always start signed out with throwaway storage.
        if PersistenceController.isTesting {
            defaults = UserDefaults(suiteName: "uiTesting")!
            defaults.removePersistentDomain(forName: "uiTesting")
            avatarDirectory = FileManager.default.temporaryDirectory
        } else {
            defaults = .standard
            avatarDirectory = URL.applicationSupportDirectory
        }
        if let id = defaults.string(forKey: currentKey), let saved = savedProfiles[id] {
            profile = saved
            avatar = loadAvatar(for: id)
        }
    }

    // MARK: Sign in

    func continueAsGuest() {
        withAnimation(.smooth) { setProfile(Profile(userID: "guest-\(UUID().uuidString)", kind: .guest)) }
    }

    /// Handles the Sign in with Apple result. If a guest is upgrading, their
    /// local groups are relinked to the Apple account through `relink`.
    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>, relink: (String, String) throws -> Void) throws {
        let authorization = try result.get()
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }

        let appleID = credential.user
        // Apple only sends the name and email the first time; keep what we had.
        var next = savedProfiles[appleID] ?? Profile(userID: appleID, kind: .apple)
        if next.displayName.isEmpty, let name = credential.fullName {
            next.displayName = PersonNameComponentsFormatter.localizedString(from: name, style: .default)
        }
        next.email = credential.email ?? next.email

        if let guest = profile, guest.kind == .guest {
            try relink(guest.userID, appleID)
            if next.displayName.isEmpty { next.displayName = guest.displayName }
            if let avatarData = avatar?.jpegData(compressionQuality: 0.85) { saveAvatar(avatarData, for: appleID) }
            forget(guest.userID)
        }
        withAnimation(.smooth) {
            setProfile(next)
            avatar = loadAvatar(for: appleID)
        }
    }

    /// Signs out if the Apple ID was revoked or the user stopped using Sign in with Apple.
    func verifyAppleCredential() async {
        guard let profile, profile.kind == .apple else { return }
        let state = try? await ASAuthorizationAppleIDProvider().credentialState(forUserID: profile.userID)
        if state == .revoked || state == .notFound { signOut() }
    }

    // MARK: Profile

    func updateProfile(displayName: String, avatarData: Data?) {
        guard var current = profile else { return }
        current.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let avatarData { saveAvatar(avatarData, for: current.userID) }
        withAnimation(.smooth) {
            setProfile(current)
            avatar = loadAvatar(for: current.userID)
        }
    }

    func removeAvatar() {
        guard let userID else { return }
        try? FileManager.default.removeItem(at: avatarURL(for: userID))
        withAnimation(.smooth) { avatar = nil }
    }

    // MARK: Sign out / delete

    /// Local groups stay on the device; signing back in picks them up again.
    func signOut() {
        defaults.removeObject(forKey: currentKey)
        withAnimation(.smooth) {
            profile = nil
            avatar = nil
        }
    }

    /// Removes the profile and photo. The caller deletes the person's groups.
    func deleteAccount() {
        guard let userID else { return }
        forget(userID)
        signOut()
    }

    // MARK: Storage

    private var savedProfiles: [String: Profile] {
        get {
            guard let data = defaults.data(forKey: profilesKey) else { return [:] }
            return (try? JSONDecoder().decode([String: Profile].self, from: data)) ?? [:]
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: profilesKey) }
    }

    private func setProfile(_ new: Profile) {
        savedProfiles[new.userID] = new
        defaults.set(new.userID, forKey: currentKey)
        profile = new
    }

    private func forget(_ userID: String) {
        savedProfiles[userID] = nil
        try? FileManager.default.removeItem(at: avatarURL(for: userID))
    }

    private func avatarURL(for userID: String) -> URL {
        let safe = userID.replacingOccurrences(of: ".", with: "_")
        return avatarDirectory.appending(path: "avatar-\(safe).jpg")
    }

    private func saveAvatar(_ data: Data, for userID: String) {
        try? FileManager.default.createDirectory(at: avatarDirectory, withIntermediateDirectories: true)
        // Downscale so a full-resolution photo doesn't sit around in storage.
        let image = UIImage(data: data).map { $0.preparingThumbnail(of: CGSize(width: 400, height: 400 * $0.size.height / max($0.size.width, 1))) ?? $0 }
        try? image?.jpegData(compressionQuality: 0.85)?.write(to: avatarURL(for: userID))
    }

    private func loadAvatar(for userID: String) -> UIImage? {
        UIImage(contentsOfFile: avatarURL(for: userID).path)
    }
}
