#if os(iOS)

import SwiftUI
import PhotosUI
import UIKit

struct PadUserProfileScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthRepository.self) private var authRepo

    @State private var fullName: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var cropperDraftData: Data?
    @State private var isSaving = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("profile.user.section.avatar") {
                    HStack {
                        Spacer()
                        avatarView
                        Spacer()
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("profile.user.avatar.choose", systemImage: "photo")
                    }
                }

                Section("profile.user.section.account") {
                    TextField("profile.user.account.fullName", text: $fullName)
                    LabeledContent("profile.user.account.email") {
                        Text(authRepo.currentUser?.email ?? "-")
                            .foregroundStyle(.secondary)
                    }
                }

                if let message {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("profile.user.title")
            .modalInlineTitleDisplayMode()
            .toolbar {
                ModalCloseToolbarItem {
                    dismiss()
                }
                ModalConfirmToolbarItem(
                    isDisabled: isSaving,
                    isProcessing: isSaving,
                    action: {
                        Task { await save() }
                    }
                )
            }
            .task {
                fullName = authRepo.currentUser?.fullName ?? ""
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self) {
                        cropperDraftData = data
                    }
                }
            }
            .fullScreenCover(isPresented: cropperPresented) {
                if let cropperDraftData {
                    PadAvatarCropperView(
                        imageData: cropperDraftData,
                        onCancel: {
                            self.cropperDraftData = nil
                        },
                        onSave: { data in
                            self.selectedImageData = data
                            self.cropperDraftData = nil
                        }
                    )
                }
            }
        }
    }

    /// Provides a writable binding for the cropper sheet presentation.
    private var cropperPresented: Binding<Bool> {
        Binding(
            get: { cropperDraftData != nil },
            set: { isPresented in
                if !isPresented {
                    cropperDraftData = nil
                }
            }
        )
    }

    private var avatarView: some View {
        Group {
            if let selectedImageData, let image = UIImage(data: selectedImageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let user = authRepo.currentUser,
                      let localURL = AvatarCache.shared.existingURL(userId: user.id, version: user.avatarVersion) {
                AsyncImage(url: localURL) { phase in
                    switch phase {
                    case .empty:
                        placeholderAvatar
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholderAvatar
                    @unknown default:
                        placeholderAvatar
                    }
                }
            } else if let avatarURL = authRepo.currentUser?.effectiveAvatarURL,
                      let url = URL(string: avatarURL),
                      !avatarURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholderAvatar
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholderAvatar
                    @unknown default:
                        placeholderAvatar
                    }
                }
            } else {
                placeholderAvatar
            }
        }
        .frame(width: 110, height: 110)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
    }

    private var placeholderAvatar: some View {
        Image("default-avatar")
            .resizable()
            .scaledToFill()
    }

    /// Saves profile changes and uploads a prepared avatar when provided.
    private func save() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let cleanName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            try await authRepo.completeProfile(fullName: cleanName.isEmpty ? String(localized: "profile.user.defaultName") : cleanName, avatarUrl: nil)

            if let selectedImageData {
                try await authRepo.uploadAvatar(imageData: selectedImageData)
            }

            message = String(localized: "profile.user.message.updated")
            dismiss()
        } catch {
            Log.dbError("profile save flow", error)
            message = "\(String(localized: "profile.user.message.failedPrefix")) \(error.localizedDescription)"
        }
    }
}

#Preview {
    let repo = AuthMock.makeRepository(isLoggedIn: true)
    PadUserProfileScreen()
        .environment(repo)
}

#endif
