import SwiftUI

struct ProfileHubView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthStore.self) private var authStore

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    NavigationLink {
                        UserProfileView()
                    } label: {
                        Label("Profile", systemImage: "person.crop.circle")
                    }

                    NavigationLink {
                        AppSettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }

                Section("Session") {
                    Button(role: .destructive) {
                        Task { await authStore.signOut() }
                    } label: {
                        Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview("Profile Hub") {
    let user = UserProfile(id: UUID(), email: "preview@ufo.app", fullName: "Preview User", role: "admin")
    let authRepo = AuthRepository(client: SupabaseConfig.client, isLoggedIn: true, currentUser: user)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    let authStore = AuthStore(authRepository: authRepo, spaceRepository: spaceRepo)
    authStore.state = .ready

    return ProfileHubView()
        .environment(authStore)
}
