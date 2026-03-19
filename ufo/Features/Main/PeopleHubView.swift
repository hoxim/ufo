import SwiftUI
import SwiftData

struct PeopleHubView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthStore.self) private var authStore
    @Environment(SpaceRepository.self) private var spaceRepository

    @State private var members: [SpaceMemberRecipient] = []
    @State private var customRoles: [SpaceRoleDefinition] = []
    @State private var editingRole: SpaceRoleDefinition?
    @State private var isShowingRoleCreator = false
    @State private var roleToDelete: SpaceRoleDefinition?
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
        if let selectedSpace {
            return "People in \(selectedSpace.name)"
        }
        return "People"
    }

    var body: some View {
        NavigationStack {
            List {
                if let lastErrorMessage, !lastErrorMessage.isEmpty {
                    Section {
                        Text(lastErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("people.hub.section.quickActions") {
                    NavigationLink {
                        MessagesView()
                    } label: {
                        Label("people.hub.action.messages", systemImage: "message")
                    }

                    NavigationLink {
                        LocationsView()
                    } label: {
                        Label("people.hub.action.locations", systemImage: "map")
                    }
                }

                Section(selectedSpace.map { "People in \($0.name)" } ?? "Członkowie") {
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

                Section {
                    ForEach(SpaceBuiltInRole.allCases) { role in
                        roleDefinitionRow(role.descriptor, isInUse: members.contains(where: { $0.role == role.rawValue }))
                    }

                    ForEach(customRoles) { role in
                        roleDefinitionRow(
                            role.resolvedDescriptor,
                            isInUse: members.contains(where: { $0.role == role.roleKey })
                        )
                    }
                } header: {
                    HStack {
                        Text("Role")
                        Spacer()
                        if canManageRoles {
                            Button {
                                isShowingRoleCreator = true
                            } label: {
                                Label("Nowa rola", systemImage: "plus")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } footer: {
                    Text("Role systemowe są gotowe od razu. Role własne możesz dopasować do swojej rodziny albo zespołu, np. Kid, Gość albo Opiekun.")
                }
            }
            .navigationTitle(peopleNavigationTitle)
            .task {
                await refreshData()
            }
            .onChange(of: selectedSpace?.id) { _, _ in
                Task { await refreshData() }
            }
            .sheet(isPresented: $isShowingRoleCreator) {
                if let selectedSpace {
                    NavigationStack {
                        SpaceRoleEditorView(spaceId: selectedSpace.id) {
                            loadCustomRoles()
                        }
                    }
                }
            }
            .sheet(item: $editingRole) { role in
                NavigationStack {
                    SpaceRoleEditorView(role: role, spaceId: role.spaceId) {
                        loadCustomRoles()
                    }
                }
            }
            .alert(
                "Usunąć rolę?",
                isPresented: Binding(
                    get: { roleToDelete != nil },
                    set: { if !$0 { roleToDelete = nil } }
                ),
                presenting: roleToDelete
            ) { role in
                Button("Usuń", role: .destructive) {
                    deleteRole(role)
                }
                Button("Anuluj", role: .cancel) {
                    roleToDelete = nil
                }
            } message: { role in
                Text("Rola \(role.name) zostanie usunięta tylko z tego urządzenia. Jeśli jest przypisana komuś w grupie, najpierw zmień tę osobę na inną rolę.")
            }
        }
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

    @ViewBuilder
    private func roleDefinitionRow(_ role: SpaceRoleDescriptor, isInUse: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(role.name)
                    .font(.headline)
                if role.isBuiltIn {
                    Text("Systemowa")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                }
                Spacer()
                if isInUse {
                    Text("Używana")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(permissionSummary(for: role.permissions))
                .font(.caption)
                .foregroundStyle(.secondary)

            if canManageRoles, !role.isBuiltIn,
               let customRole = customRoles.first(where: { $0.roleKey == role.key }) {
                HStack(spacing: 12) {
                    Button("Edytuj") {
                        editingRole = customRole
                    }
                    .buttonStyle(.borderless)

                    Button("Usuń", role: .destructive) {
                        roleToDelete = customRole
                    }
                    .buttonStyle(.borderless)
                    .disabled(isInUse)
                }
                .font(.caption.weight(.semibold))
            }
        }
        .padding(.vertical, 4)
    }

    private func permissionSummary(for permissions: SpaceRolePermissions) -> String {
        var values: [String] = ["podgląd"]

        if permissions.canCreateItems { values.append("dodawanie") }
        if permissions.canEditItems { values.append("edycja") }
        if permissions.canDeleteItems { values.append("usuwanie") }
        if permissions.canInviteMembers { values.append("zapraszanie") }
        if permissions.canManageGroupSettings { values.append("ustawienia grupy") }
        if permissions.canManageRoles { values.append("zarządzanie rolami") }

        return values.joined(separator: " • ")
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

    private func deleteRole(_ role: SpaceRoleDefinition) {
        modelContext.delete(role)
        do {
            try modelContext.save()
            roleToDelete = nil
            loadCustomRoles()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}

private struct SpaceRoleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let role: SpaceRoleDefinition?
    let spaceId: UUID
    let onSave: () -> Void

    @State private var name: String
    @State private var canCreateItems: Bool
    @State private var canEditItems: Bool
    @State private var canDeleteItems: Bool
    @State private var canInviteMembers: Bool
    @State private var canManageGroupSettings: Bool
    @State private var canManageRoles: Bool

    init(role: SpaceRoleDefinition? = nil, spaceId: UUID, onSave: @escaping () -> Void) {
        self.role = role
        self.spaceId = spaceId
        self.onSave = onSave
        _name = State(initialValue: role?.name ?? "")
        _canCreateItems = State(initialValue: role?.canCreateItems ?? true)
        _canEditItems = State(initialValue: role?.canEditItems ?? false)
        _canDeleteItems = State(initialValue: role?.canDeleteItems ?? false)
        _canInviteMembers = State(initialValue: role?.canInviteMembers ?? false)
        _canManageGroupSettings = State(initialValue: role?.canManageGroupSettings ?? false)
        _canManageRoles = State(initialValue: role?.canManageRoles ?? false)
    }

    var body: some View {
        Form {
            Section("Rola") {
                TextField("Np. Kid, Gość, Opiekun", text: $name)
            }

            Section("Uprawnienia") {
                Toggle("Może dodawać", isOn: $canCreateItems)
                Toggle("Może edytować", isOn: $canEditItems)
                Toggle("Może usuwać", isOn: $canDeleteItems)
                Toggle("Może zapraszać osoby", isOn: $canInviteMembers)
                Toggle("Może zmieniać ustawienia grupy", isOn: $canManageGroupSettings)
                Toggle("Może zarządzać rolami", isOn: $canManageRoles)
            }
        }
        .navigationTitle(role == nil ? "Nowa rola" : "Edytuj rolę")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("common.cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Zapisz") {
                    save()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }

        if let role {
            role.name = cleanName
            role.key = SpaceRoleDefinition.makeKey(from: cleanName)
            role.canCreateItems = canCreateItems
            role.canEditItems = canEditItems
            role.canDeleteItems = canDeleteItems
            role.canInviteMembers = canInviteMembers
            role.canManageGroupSettings = canManageGroupSettings
            role.canManageRoles = canManageRoles
            role.updatedAt = .now
        } else {
            modelContext.insert(
                SpaceRoleDefinition(
                    spaceId: spaceId,
                    name: cleanName,
                    canCreateItems: canCreateItems,
                    canEditItems: canEditItems,
                    canDeleteItems: canDeleteItems,
                    canInviteMembers: canInviteMembers,
                    canManageGroupSettings: canManageGroupSettings,
                    canManageRoles: canManageRoles
                )
            )
        }

        do {
            try modelContext.save()
            onSave()
            dismiss()
        } catch {
            Log.dbError("PeopleHub.saveRole", error)
        }
    }
}

private extension SpaceRoleDefinition {
    var resolvedDescriptor: SpaceRoleDescriptor {
        SpaceRoleDescriptor(
            key: roleKey,
            name: name,
            permissions: SpaceRolePermissions(
                canCreateItems: canCreateItems,
                canEditItems: canEditItems,
                canDeleteItems: canDeleteItems,
                canInviteMembers: canInviteMembers,
                canManageGroupSettings: canManageGroupSettings,
                canManageRoles: canManageRoles
            ),
            isBuiltIn: false
        )
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

    return PeopleHubView()
        .environment(spaceRepo)
        .environment(authStore)
        .modelContainer(container)
}
