#if os(macOS)

//
//  MacSpacesScreen.swift
//  ufo
//
//  Created by Marcin Ryzko on 09/02/2026.
//

import SwiftUI

struct MacSpacesScreen: View {
    @Environment(AuthRepository.self) private var authRepo
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthStore.self) private var authStore
    
    @State private var spaceToEdit: Space?
    @State private var spaceToInvite: Space?
    @State private var isShowingCreator = false
    @State private var membersBySpaceID: [UUID: [SpaceMemberRecipient]] = [:]
    @State private var pendingAction: MacSpacePendingAction?
    @State private var selectedFilter: MacSpaceFilter = .all
    @State private var searchText = ""
    @State private var expandedSpaceIDs: Set<UUID> = []
    
    var body: some View {
        ScrollView {
            if let user = authRepo.currentUser {
                if user.memberships.isEmpty {
                    ContentUnavailableView("spaces.list.empty.title", systemImage: "person.3.slash", description: Text("spaces.list.empty.body"))
                        .frame(maxWidth: .infinity, minHeight: 320)
                } else {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        filterBar

                        if filteredMemberships(from: user.memberships).isEmpty {
                            ContentUnavailableView(
                                "Brak pasujących grup",
                                systemImage: "person.3.sequence",
                                description: Text("Spróbuj zmienić filtr albo frazę wyszukiwania.")
                            )
                            .frame(maxWidth: .infinity, minHeight: 240)
                            .padding(.top, 20)
                        }

                        ForEach(filteredMemberships(from: user.memberships)) { membership in
                            if let space = membership.space {
                                MacSpaceCard(
                                    space: space,
                                    role: membership.role,
                                    isSelected: spaceRepo.selectedSpace?.id == space.id,
                                    isExpanded: expandedSpaceIDs.contains(space.id),
                                    members: membersBySpaceID[space.id] ?? [],
                                    onSelect: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                            spaceRepo.selectedSpace = space
                                        }
                                    },
                                    onToggleExpanded: {
                                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                            if expandedSpaceIDs.contains(space.id) {
                                                expandedSpaceIDs.remove(space.id)
                                            } else {
                                                expandedSpaceIDs.insert(space.id)
                                            }
                                        }
                                    },
                                    onInvite: { spaceToInvite = space },
                                    onEdit: { spaceToEdit = space },
                                    onDeleteOrLeave: {
                                        pendingAction = membership.role == "admin"
                                            ? .delete(space, membership.role)
                                            : .leave(space, membership.role)
                                    }
                                )
                                .contextMenu {
                                    spaceContextMenu(for: space, role: membership.role)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .appScreenBackground()
        .navigationTitle("Grupy")
        .searchable(text: $searchText, prompt: "Szukaj grupy lub kodu")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingCreator = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        // Sheet for new space creation
        .sheet(isPresented: $isShowingCreator) {
            MacSpaceEditorView()
        }
        // Sheet for space edition
        .sheet(item: $spaceToEdit) { space in
            MacSpaceEditorView(space: space)
        }
        // Sheet for invitations
        .sheet(item: $spaceToInvite) { space in
            MacInviteMemberView(space: space)
                .presentationDetents([.medium])
        }
        .task {
            await loadMembers()
        }
        .onChange(of: authRepo.currentUser?.memberships.count) { _, _ in
            Task { await loadMembers() }
        }
        .alert(
            pendingAction?.title ?? "",
            isPresented: Binding(
                get: { pendingAction != nil },
                set: { if !$0 { pendingAction = nil } }
            ),
            presenting: pendingAction
        ) { action in
            Button(action.confirmTitle, role: .destructive) {
                Task { await perform(action) }
            }
            Button("common.cancel", role: .cancel) {
                pendingAction = nil
            }
        } message: { action in
            Text(action.message)
        }
    }

    @ViewBuilder
    private func spaceContextMenu(for space: Space, role: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                spaceRepo.selectedSpace = space
            }
        } label: {
            Label("Wybierz tę grupę", systemImage: "checkmark.circle")
        }

        if role == "admin" {
            Button {
                spaceToInvite = space
            } label: {
                Label("Zaproś osobę", systemImage: "person.badge.plus")
            }
            .disabled(!space.allowsInvitations)

            Button {
                spaceToEdit = space
            } label: {
                Label("Edytuj grupę", systemImage: "pencil")
            }

            Button(role: .destructive) {
                pendingAction = .delete(space, role)
            } label: {
                Label("Usuń grupę", systemImage: "trash")
            }
        } else {
            Button(role: .destructive) {
                pendingAction = .leave(space, role)
            } label: {
                Label("Opuść grupę", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
    }

    private func loadMembers() async {
        guard let memberships = authRepo.currentUser?.memberships else { return }

        var newMembersBySpaceID: [UUID: [SpaceMemberRecipient]] = [:]
        for membership in memberships {
            guard let space = membership.space else { continue }
            do {
                newMembersBySpaceID[space.id] = try await spaceRepo.fetchMembers(spaceId: space.id)
            } catch {
                newMembersBySpaceID[space.id] = []
            }
        }
        membersBySpaceID = newMembersBySpaceID
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wybierz przestrzeń, z której aplikacja ma pobierać dane.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ForEach(MacSpaceFilter.allCases) { filter in
                    Button {
                        withAnimation(.snappy(duration: 0.24)) {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedFilter == filter ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Group {
                                    if selectedFilter == filter {
                                        Capsule().fill(Color.accentColor)
                                    } else {
                                        Capsule().fill(Color.secondarySystemBackgroundAdaptive)
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func filteredMemberships(from memberships: [SpaceMembership]) -> [SpaceMembership] {
        memberships.filter { membership in
            guard let space = membership.space else { return false }

            let matchesFilter = switch selectedFilter {
            case .all:
                true
            case .shared:
                space.type == .shared
            case .private:
                space.type == .private || space.type == .personal
            }

            guard matchesFilter else { return false }

            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return true }

            let haystacks = [
                space.name,
                space.inviteCode,
                membership.role,
                space.type.displayName
            ]

            return haystacks.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private func perform(_ action: MacSpacePendingAction) async {
        defer { pendingAction = nil }

        switch action {
        case .delete(let space, _):
            do {
                try await spaceRepo.deleteSpace(spaceId: space.id)
                await authStore.refreshProfileAndSpaces()
            } catch {
                return
            }
        case .leave(let space, _):
            do {
                try await spaceRepo.leaveSpace(spaceId: space.id)
                await authStore.refreshProfileAndSpaces()
            } catch {
                return
            }
        }
    }
}

#Preview("Space List") {
    let user = UserProfile(id: UUID(), email: "user@ufo.app", fullName: "Test User")
    let privateSpace = Space(id: UUID(), name: "Personal Space", inviteCode: "PER123", category: SpaceType.personal.rawValue)
    let sharedSpace = Space(id: UUID(), name: "Family HQ", inviteCode: "FAM456", category: SpaceType.shared.rawValue)
    let m1 = SpaceMembership(user: user, space: privateSpace, role: "admin")
    let m2 = SpaceMembership(user: user, space: sharedSpace, role: "member")
    user.memberships = [m1, m2]

    let authRepo = AuthRepository(client: SupabaseConfig.client, isLoggedIn: true, currentUser: user)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    let authStore = AuthStore(authRepository: authRepo, spaceRepository: spaceRepo)
    authStore.state = .ready
    spaceRepo.selectedSpace = sharedSpace

    return MacSpacesScreen()
        .environment(authRepo)
        .environment(spaceRepo)
        .environment(authStore)
}

#endif
