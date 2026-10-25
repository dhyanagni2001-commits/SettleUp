//
//  AccountView.swift
//  SplitWiseClone
//
//  Edit profile, upgrade a guest to Sign in with Apple, sign out, and
//  delete the account along with its data.
//

import AuthenticationServices
import PhotosUI
import SwiftUI

struct AccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var account: AccountStore
    @EnvironmentObject private var groupList: GroupListViewModel

    @State private var name = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var confirmingDelete = false
    @State private var confirmingSignOut = false
    @State private var errorMessage: String?

    private var isGuest: Bool { account.profile?.kind == .guest }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            let displayName = account.profile?.displayName ?? "?", avatar = account.avatar
                            PhotosPicker(selection: $photoItem, matching: .images) {
                                ProfileAvatarImage(name: displayName, image: avatar, size: 92)
                            }
                            .accessibilityLabel("Change profile photo")
                            Text(isGuest ? "Guest" : "Signed in with Apple")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.subtext)
                            if let email = account.profile?.email {
                                Text(email).font(.footnote).foregroundStyle(Color.subtext)
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Display name") {
                    TextField("Your name", text: $name)
                        .submitLabel(.done)
                        .onSubmit(saveName)
                    if account.avatar != nil {
                        Button("Remove Photo", role: .destructive) { account.removeAvatar() }
                    }
                }

                if isGuest {
                    Section {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            do {
                                try account.completeAppleSignIn(result, relink: groupList.relinkUser)
                            } catch let error as ASAuthorizationError where error.code == .canceled {
                            } catch {
                                errorMessage = "Sign in didn't complete: \(error.localizedDescription)"
                            }
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 48)
                        .clipShape(Capsule())
                        .listRowBackground(Color.clear)
                    } footer: {
                        Text("Your groups and expenses on this device stay exactly as they are.")
                    }
                }

                Section {
                    NavigationLink {
                        SiriHelpView()
                    } label: {
                        Label("Siri & Shortcuts", systemImage: "waveform")
                    }
                }

                Section {
                    Button("Sign Out") { confirmingSignOut = true }
                    Button("Delete Account and Data", role: .destructive) { confirmingDelete = true }
                } footer: {
                    Text("Deleting removes your profile and the groups you created, here and in iCloud. Groups others shared with you stay with them.")
                }
            }
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { saveName(); dismiss() }
                }
            }
            .onAppear { name = account.profile?.displayName ?? "" }
            .onChange(of: photoItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        account.updateProfile(displayName: name, avatarData: data)
                    }
                }
            }
            .confirmationDialog("Sign out?", isPresented: $confirmingSignOut, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) { account.signOut() }
            } message: {
                Text(isGuest
                     ? "Your groups stay on this device, but this guest profile can't be recovered. Sign in with Apple first to keep it."
                     : "Your groups stay on this device and in iCloud.")
            }
            .confirmationDialog("Delete your account?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete Account and Data", role: .destructive) {
                    groupList.deleteAllData(for: account.userID)
                    account.deleteAccount()
                }
            } message: {
                Text("This can't be undone.")
            }
            .errorAlert($errorMessage)
        }
    }

    private func saveName() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != account.profile?.displayName else { return }
        account.updateProfile(displayName: trimmed, avatarData: nil)
    }
}
