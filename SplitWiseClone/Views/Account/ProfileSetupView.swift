//
//  ProfileSetupView.swift
//  SplitWiseClone
//
//  Shown once after sign-in: a display name (required) and photo (optional).
//

import PhotosUI
import SwiftUI

struct ProfileSetupView: View {
    @EnvironmentObject private var account: AccountStore
    @State private var name = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var appeared = false
    @FocusState private var nameFocused: Bool

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 8) {
                Text("What should we call you?")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                Text("Friends see this name in shared groups.")
                    .foregroundStyle(Color.subtext)
            }
            .multilineTextAlignment(.center)
            .rise(appeared, delay: 0)

            PhotosPicker(selection: $photoItem, matching: .images) {
                ProfileAvatarImage(name: trimmedName.isEmpty ? "?" : trimmedName,
                                   image: photoData.flatMap(UIImage.init(data:)), size: 112)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "camera.fill")
                            .font(.footnote.bold())
                            .foregroundStyle(.black)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.brand))
                            .overlay(Circle().stroke(Color.base, lineWidth: 3))
                    }
            }
            .accessibilityLabel("Choose profile photo")
            .rise(appeared, delay: 0.08)

            TextField("Your name", text: $name)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .textContentType(.name)
                .submitLabel(.done)
                .focused($nameFocused)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.card))
                .padding(.horizontal, 24)
                .onSubmit(save)
                .rise(appeared, delay: 0.14)

            Spacer()

            Button("Continue", action: save)
                .buttonStyle(BrandButtonStyle())
                .disabled(trimmedName.isEmpty)
                .opacity(trimmedName.isEmpty ? 0.5 : 1)
                .animation(.smooth, value: trimmedName.isEmpty)
                .rise(appeared, delay: 0.2)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
        .background { AppBackground() }
        .onAppear {
            name = account.profile?.displayName ?? ""
            appeared = true
            nameFocused = true
        }
        .onChange(of: photoItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { photoData = data }
                }
            }
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        account.updateProfile(displayName: trimmedName, avatarData: photoData)
    }
}

/// Profile photo if there is one, else the initial avatar.
struct ProfileAvatarImage: View {
    let name: String
    let image: UIImage?
    var size: CGFloat = 34

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .transition(.scale.combined(with: .opacity))
            } else {
                Avatar(name: name, size: size)
                    .transition(.opacity)
            }
        }
        .animation(.smooth, value: image)
    }
}

#Preview {
    ProfileSetupView()
        .environmentObject(AccountStore())
        .preferredColorScheme(.dark)
}
