import SwiftUI
import PhotosUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct UserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthRepository.self) private var authRepo

    @State private var fullName: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isSaving = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Avatar") {
                    HStack {
                        Spacer()
                        avatarView
                        Spacer()
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Choose avatar", systemImage: "photo")
                    }
                }

                Section("Account") {
                    TextField("Full name", text: $fullName)
                    LabeledContent("Email") {
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
            .navigationTitle("User Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .task {
                fullName = authRepo.currentUser?.fullName ?? ""
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self) {
                        selectedImageData = data
                    }
                }
            }
        }
    }

    private var avatarView: some View {
        Group {
            #if os(iOS)
            if let selectedImageData, let image = UIImage(data: selectedImageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let avatarURL = authRepo.currentUser?.avatarURL,
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
            #elseif os(macOS)
            if let selectedImageData, let image = NSImage(data: selectedImageData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let avatarURL = authRepo.currentUser?.avatarURL,
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
            #else
            placeholderAvatar
            #endif
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

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let cleanName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            try await authRepo.completeProfile(fullName: cleanName.isEmpty ? "User" : cleanName, avatarUrl: nil)

            if let selectedImageData {
                try await authRepo.uploadAvatar(imageData: selectedImageData, fileName: "avatar.jpg")
            }

            message = "Profile updated"
            dismiss()
        } catch {
            message = "Failed to update profile: \(error.localizedDescription)"
        }
    }
}

#Preview {
    let repo = AuthMock.makeRepository(isLoggedIn: true)
    UserProfileView()
        .environment(repo)
}
