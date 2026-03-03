import SwiftUI

struct PeopleHubView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(SpaceRepository.self) private var spaceRepository

    var body: some View {
        NavigationStack {
            List {
                Section("Quick Actions") {
                    NavigationLink {
                        MessagesView()
                    } label: {
                        Label("Messages", systemImage: "message")
                    }

                    NavigationLink {
                        LocationsView()
                    } label: {
                        Label("Locations", systemImage: "map")
                    }
                }

                Section("People in current space") {
                    if let selectedSpace = spaceRepository.selectedSpace, !selectedSpace.members.isEmpty {
                        ForEach(selectedSpace.members) { membership in
                            let displayName = membership.user?.fullName ?? membership.user?.email ?? "Unknown user"
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(displayName)
                                    Text(membership.role.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .contextMenu {
                                NavigationLink {
                                    MessagesView()
                                } label: {
                                    Label("Send message", systemImage: "message")
                                }

                                NavigationLink {
                                    LocationsView()
                                } label: {
                                    Label("Find on map", systemImage: "location")
                                }
                            }
                        }
                    } else {
                        if let user = authStore.currentUser {
                            ForEach(user.memberships.filter { $0.spaceId == spaceRepository.selectedSpace?.id }) { membership in
                                let displayName = membership.user?.fullName ?? membership.user?.email ?? user.fullName ?? user.email
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(displayName)
                                    Text(membership.role.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            Text("No people data in this space yet.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("People")
        }
    }
}

#Preview("People Hub") {
    let user = UserProfile(id: UUID(), email: "preview@ufo.app", fullName: "Preview User", role: "admin")
    let space = Space(id: UUID(), name: "Family Crew", inviteCode: "UFO123")
    let membership = SpaceMembership(user: user, space: space, role: "admin")
    user.memberships = [membership]

    let authRepo = AuthRepository(client: SupabaseConfig.client, isLoggedIn: true, currentUser: user)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    spaceRepo.selectedSpace = space
    let authStore = AuthStore(authRepository: authRepo, spaceRepository: spaceRepo)
    authStore.state = .ready

    return PeopleHubView()
        .environment(authRepo)
        .environment(spaceRepo)
        .environment(authStore)
}
