#if os(iOS)

import SwiftUI

struct PadProfileScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthStore.self) private var authStore

    var body: some View {
        NavigationStack {
            List {
                Section("profile.hub.section.account") {
                    NavigationLink {
                        PadUserProfileScreen()
                    } label: {
                        Label("profile.hub.action.profile", systemImage: "person.crop.circle")
                    }

                    NavigationLink {
                        PadSettingsScreen()
                    } label: {
                        Label("profile.hub.action.settings", systemImage: "gearshape")
                    }
                }

                Section("profile.hub.section.session") {
                    Button(role: .destructive) {
                        Task { await authStore.signOut() }
                    } label: {
                        Label("profile.hub.action.logout", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("profile.hub.title")
            .modalInlineTitleDisplayMode()
            .toolbar {
                ModalCloseToolbarItem { dismiss() }
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

    return PadProfileScreen()
        .environment(authStore)
}

#endif
