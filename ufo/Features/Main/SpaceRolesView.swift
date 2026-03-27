import SwiftUI
import SwiftData

struct SpaceRolesView: View {
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

    var body: some View {
        List {
            if let lastErrorMessage, !lastErrorMessage.isEmpty {
                Section {
                    Text(lastErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if selectedSpace == nil {
                ContentUnavailableView(
                    "Wybierz grupę",
                    systemImage: "person.3.sequence",
                    description: Text("Najpierw wybierz grupę, żeby zobaczyć role i nimi zarządzać.")
                )
                .frame(maxWidth: .infinity, minHeight: 220)
                .listRowBackground(Color.clear)
            } else {
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
        }
        .appPrimaryListChrome()
        .appScreenBackground()
        .navigationTitle("Roles")
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

    @ViewBuilder
    private func roleDefinitionRow(_ role: SpaceRoleDescriptor, isInUse: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
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

struct SpaceRoleEditorView: View {
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
        .modalInlineTitleDisplayMode()
        .toolbar {
            ModalCloseToolbarItem {
                dismiss()
            }
            ModalConfirmToolbarItem(
                isDisabled: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                isProcessing: false,
                action: save
            )
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
            Log.dbError("SpaceRolesView.saveRole", error)
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
