#if os(iOS)

import SwiftUI
import SwiftData

struct PadRolesScreen: View {
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
                    "spaces.selector.choose",
                    systemImage: "person.3.sequence",
                    description: Text("roles.empty.noSpace")
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
                        Text("navigation.item.roles")
                        Spacer()
                        if canManageRoles {
                            Button {
                                isShowingRoleCreator = true
                            } label: {
                                Label("roles.action.new", systemImage: "plus")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } footer: {
                    Text("roles.footer.description")
                }
            }
        }
        .appPrimaryListChrome()
        .appScreenBackground()
        .navigationTitle("navigation.item.roles")
        .task {
            await refreshData()
        }
        .onChange(of: selectedSpace?.id) { _, _ in
            Task { await refreshData() }
        }
        .sheet(isPresented: $isShowingRoleCreator) {
            if let selectedSpace {
                NavigationStack {
                    PadRoleEditorScreen(spaceId: selectedSpace.id) {
                        loadCustomRoles()
                    }
                }
            }
        }
        .sheet(item: $editingRole) { role in
            NavigationStack {
                PadRoleEditorScreen(role: role, spaceId: role.spaceId) {
                    loadCustomRoles()
                }
            }
        }
        .alert(
            "roles.alert.delete.title",
            isPresented: Binding(
                get: { roleToDelete != nil },
                set: { if !$0 { roleToDelete = nil } }
            ),
            presenting: roleToDelete
        ) { role in
            Button("common.delete", role: .destructive) {
                deleteRole(role)
            }
            Button("common.cancel", role: .cancel) {
                roleToDelete = nil
            }
        } message: { role in
            Text(String(format: String(localized: "roles.alert.delete.message"), role.name))
        }
    }

    @ViewBuilder
    private func roleDefinitionRow(_ role: SpaceRoleDescriptor, isInUse: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(role.name)
                    .font(.headline)

                if role.isBuiltIn {
                    Text("roles.badge.system")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                }

                Spacer()

                if isInUse {
                    Text("roles.badge.inUse")
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
                    Button("common.edit") {
                        editingRole = customRole
                    }
                    .buttonStyle(.borderless)

                    Button("common.delete", role: .destructive) {
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
        localizedRolePermissionSummary(permissions)
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

struct PadRoleEditorScreen: View {
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
            Section("roles.editor.section.role") {
                TextField("roles.editor.placeholder.name", text: $name)
            }

            Section("roles.editor.section.permissions") {
                Toggle("roles.editor.permission.create", isOn: $canCreateItems)
                Toggle("roles.editor.permission.edit", isOn: $canEditItems)
                Toggle("roles.editor.permission.delete", isOn: $canDeleteItems)
                Toggle("roles.editor.permission.invite", isOn: $canInviteMembers)
                Toggle("roles.editor.permission.manageGroup", isOn: $canManageGroupSettings)
                Toggle("roles.editor.permission.manageRoles", isOn: $canManageRoles)
            }
        }
        .navigationTitle(role == nil ? "roles.editor.title.new" : "roles.editor.title.edit")
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
            Log.dbError("PadRolesScreen.saveRole", error)
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

#endif
