#if os(macOS)

import SwiftUI
import SwiftData

enum MacPeopleDisplayMode {
    case hub
    case crew
}

struct MacPeopleScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthStore.self) private var authStore
    @Environment(SpaceRepository.self) private var spaceRepository

    var displayMode: MacPeopleDisplayMode = .hub

    @State private var members: [SpaceMemberRecipient] = []
    @State private var customRoles: [SpaceRoleDefinition] = []
    @State private var lastErrorMessage: String?

    private var selectedSpace: Space? {
        spaceRepository.selectedSpace
    }

    private var currentMembership: SpaceMembership? {
        guard let spaceId = selectedSpace?.id else { return nil }
        return authStore.currentUser?.memberships.first(where: { $0.spaceId == spaceId })
    }

    private var canManageRoles: Bool {
        currentMembership?.resolvedRoleDescriptor(customRoles: customRoles).permissions.canManageRoles ?? false
    }

    private var sortedMembers: [SpaceMemberRecipient] {
        members.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private var peopleNavigationTitle: String {
        if displayMode == .crew {
            if let selectedSpace {
                return "Crew in \(selectedSpace.name)"
            }
            return "Crew"
        }
        if let selectedSpace {
            return "People in \(selectedSpace.name)"
        }
        return "People"
    }

    var body: some View {
        List {
            if let lastErrorMessage, !lastErrorMessage.isEmpty {
                Section {
                    Text(lastErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if displayMode == .hub {
                Section("Tools") {
                    NavigationLink {
                        MacMessagesScreen()
                    } label: {
                        Label("people.hub.action.messages", systemImage: "message")
                    }

                    NavigationLink {
                        MacLocationsScreen()
                    } label: {
                        Label("Places", systemImage: "map")
                    }

                    NavigationLink {
                        MacRolesScreen()
                    } label: {
                        Label("Roles", systemImage: "lock.shield")
                    }
                }
            }

            Section(memberSectionTitle) {
                if let selectedSpace {
                    if sortedMembers.isEmpty {
                        ContentUnavailableView(
                            "Brak członków",
                            systemImage: "person.2.slash",
                            description: Text("Nie udało się jeszcze wczytać osób dla grupy \(selectedSpace.name).")
                        )
                        .frame(maxWidth: .infinity, minHeight: 180)
                    } else {
                        ForEach(sortedMembers) { member in
                            memberRow(member)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "Wybierz grupę",
                        systemImage: "person.3.sequence",
                        description: Text("Najpierw wybierz grupę, żeby zobaczyć osoby i przypisać im role.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 180)
                }
            }
        }
        .appPrimaryListChrome()
        .appScreenBackground()
        .navigationTitle(peopleNavigationTitle)
        .task {
            await refreshData()
        }
        .onChange(of: selectedSpace?.id) { _, _ in
            Task { await refreshData() }
        }
    }

    private var memberSectionTitle: String {
        if let selectedSpace {
            return displayMode == .crew ? "Crew in \(selectedSpace.name)" : "People in \(selectedSpace.name)"
        }
        return displayMode == .crew ? "Crew" : "Członkowie"
    }

    @ViewBuilder
    private func memberRow(_ member: SpaceMemberRecipient) -> some View {
        let descriptor = member.resolvedRoleDescriptor(customRoles: customRoles)

        HStack(spacing: 12) {
            Circle()
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(String(member.displayName.prefix(1)).uppercased())
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(member.displayName)
                        .font(.body.weight(.medium))

                    if authStore.currentUser?.id == member.id {
                        Text("Ty")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                    }
                }
                Text(descriptor.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if canManageRoles, let selectedSpace {
                Menu {
                    roleAssignmentActions(for: member, in: selectedSpace)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func roleAssignmentActions(for member: SpaceMemberRecipient, in selectedSpace: Space) -> some View {
        Section("Role systemowe") {
            ForEach(SpaceBuiltInRole.allCases) { role in
                let isProtected = isProtectedSelfRoleChange(for: member, newRoleKey: role.rawValue)

                Button {
                    Task { await assignRole(role.rawValue, to: member, in: selectedSpace) }
                } label: {
                    let descriptor = role.descriptor
                    if member.role == role.rawValue {
                        Label(descriptor.name, systemImage: "checkmark")
                    } else {
                        Text(descriptor.name)
                    }
                }
                .disabled(isProtected)
            }
        }

        if !customRoles.isEmpty {
            Section("Role własne") {
                ForEach(customRoles) { role in
                    let isProtected = isProtectedSelfRoleChange(for: member, newRoleKey: role.roleKey)

                    Button {
                        Task { await assignRole(role.roleKey, to: member, in: selectedSpace) }
                    } label: {
                        if member.role == role.roleKey {
                            Label(role.name, systemImage: "checkmark")
                        } else {
                            Text(role.name)
                        }
                    }
                    .disabled(isProtected)
                }
            }
        }

        if authStore.currentUser?.id == member.id {
            Section {
                Text("Nie możesz obniżyć własnej roli, jeśli stracisz możliwość zarządzania grupą albo rolami.")
            }
        }
    }

    private func refreshData() async {
        await loadMembers()
        loadCustomRoles()
    }

    private func loadCustomRoles() {
        guard let spaceId = selectedSpace?.id else {
            customRoles = []
            return
        }

        do {
            customRoles = try modelContext.fetch(
                FetchDescriptor<SpaceRoleDefinition>(
                    predicate: #Predicate { $0.spaceId == spaceId },
                    sortBy: [SortDescriptor(\.name, order: .forward)]
                )
            )
        } catch {
            customRoles = []
            lastErrorMessage = error.localizedDescription
        }
    }

    private func loadMembers() async {
        guard let selectedSpace else {
            members = []
            return
        }

        let localMembers = selectedSpace.members.map {
            SpaceMemberRecipient(
                id: $0.userId,
                email: $0.user?.email ?? "",
                fullName: $0.user?.fullName,
                avatarURL: $0.user?.avatarURL,
                providerAvatarURL: $0.user?.providerAvatarURL,
                role: $0.role
            )
        }

        if !localMembers.isEmpty {
            members = localMembers
        }

        do {
            members = try await spaceRepository.fetchMembers(spaceId: selectedSpace.id)
            lastErrorMessage = nil
        } catch {
            if members.isEmpty {
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func assignRole(_ roleKey: String, to member: SpaceMemberRecipient, in selectedSpace: Space) async {
        guard member.role != roleKey else { return }

        if isProtectedSelfRoleChange(for: member, newRoleKey: roleKey) {
            lastErrorMessage = "Nie możesz obniżyć własnej roli tak, aby stracić zarządzanie grupą albo rolami."
            return
        }

        do {
            try await spaceRepository.updateMemberRole(spaceId: selectedSpace.id, userId: member.id, role: roleKey)
            await loadMembers()

            if authStore.currentUser?.id == member.id {
                await authStore.refreshProfileAndSpaces()
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func isProtectedSelfRoleChange(for member: SpaceMemberRecipient, newRoleKey: String) -> Bool {
        guard authStore.currentUser?.id == member.id else { return false }

        let currentPermissions = member.resolvedRoleDescriptor(customRoles: customRoles).permissions
        let nextPermissions = SpaceRoleDescriptor.resolve(roleKey: newRoleKey, customRoles: customRoles).permissions

        let wouldLoseRoleManagement = currentPermissions.canManageRoles && !nextPermissions.canManageRoles
        let wouldLoseGroupManagement = currentPermissions.canManageGroupSettings && !nextPermissions.canManageGroupSettings

        return wouldLoseRoleManagement || wouldLoseGroupManagement
    }
}

#Preview("People Hub") {
    let schema = Schema([
        UserProfile.self,
        Space.self,
        SpaceMembership.self,
        SpaceRoleDefinition.self
    ])
    let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext

    let user = UserProfile(id: UUID(), email: "preview@ufo.app", fullName: "Preview User", role: "admin")
    let child = UserProfile(id: UUID(), email: "kid@ufo.app", fullName: "Alex", role: "user")
    let space = Space(id: UUID(), name: "Family Crew", inviteCode: "UFO123")
    let membership = SpaceMembership(user: user, space: space, role: "admin")
    let childMembership = SpaceMembership(user: child, space: space, role: "contributor")
    let kidRole = SpaceRoleDefinition(spaceId: space.id, name: "Kid", canCreateItems: true)

    context.insert(user)
    context.insert(child)
    context.insert(space)
    context.insert(membership)
    context.insert(childMembership)
    context.insert(kidRole)
    try! context.save()

    user.memberships = [membership]
    space.members = [membership, childMembership]

    let authRepo = AuthRepository(client: SupabaseConfig.client, isLoggedIn: true, currentUser: user)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    spaceRepo.selectedSpace = space
    let authStore = AuthStore(authRepository: authRepo, spaceRepository: spaceRepo)
    authStore.state = .ready

    return MacPeopleScreen()
        .environment(spaceRepo)
        .environment(authStore)
        .modelContainer(container)
}

#endif
