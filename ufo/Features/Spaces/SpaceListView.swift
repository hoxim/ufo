//
//  SpaceListView.swift
//  ufo
//
//  Created by Marcin Ryzko on 09/02/2026.
//

import SwiftUI

struct SpaceListView: View {
    @Environment(AuthRepository.self) private var authRepo
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthStore.self) private var authStore
    
    @State private var spaceToEdit: Space?
    @State private var spaceToInvite: Space?
    @State private var isShowingCreator = false
    @State private var membersBySpaceID: [UUID: [SpaceMemberRecipient]] = [:]
    @State private var pendingAction: SpacePendingAction?
    @State private var selectedFilter: SpaceFilter = .all
    @State private var searchText = ""
    @State private var expandedSpaceIDs: Set<UUID> = []
    
    var body: some View {
        NavigationStack {
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
                                    SpaceCard(
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
            .background(Color.clear)
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
                SpaceEditorView()
            }
            // Sheet for space edition
            .sheet(item: $spaceToEdit) { space in
                SpaceEditorView(space: space)
            }
            // Sheet for invitations
            .sheet(item: $spaceToInvite) { space in
                InviteMemberView(space: space)
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
                ForEach(SpaceFilter.allCases) { filter in
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
                                        Capsule().fill(Color(.secondarySystemBackground))
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

    private func perform(_ action: SpacePendingAction) async {
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

private enum SpaceFilter: String, CaseIterable, Identifiable {
    case all
    case shared
    case `private`

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "Wszystkie"
        case .shared:
            return "Wspólne"
        case .private:
            return "Prywatne"
        }
    }
}

private struct SpaceCard: View {
    let space: Space
    let role: String
    let isSelected: Bool
    let isExpanded: Bool
    let members: [SpaceMemberRecipient]
    let onSelect: () -> Void
    let onToggleExpanded: () -> Void
    let onInvite: () -> Void
    let onEdit: () -> Void
    let onDeleteOrLeave: () -> Void

    private let cardCornerRadius: CGFloat = 22
    private let infoColumns = [GridItem(.adaptive(minimum: 110), alignment: .leading)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 10) {
                        Text(space.name)
                            .font(.title3.weight(.bold))
                        if isSelected {
                            statusBadge(title: "Aktywna grupa", tint: .green)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Label("Info", systemImage: "info.circle")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: infoColumns, alignment: .leading, spacing: 8) {
                            compactMetaPill(
                                title: space.inviteCode,
                                icon: "number",
                                tint: .secondary
                            )
                            compactMetaPill(
                                title: role == "admin" ? "Właściciel" : "Gość",
                                icon: role == "admin" ? "crown.fill" : "person.fill",
                                tint: role == "admin" ? .blue : .secondary
                            )
                            compactMetaPill(
                                title: spaceTypeLabel,
                                icon: spaceTypeSymbol,
                                tint: cardAccentColor
                            )
                        }
                    }
                }

                Spacer(minLength: 12)

                Menu {
                    Button(action: onSelect) {
                        Label("Ustaw jako aktywną", systemImage: "checkmark.circle")
                    }

                    Button(action: onToggleExpanded) {
                        Label(isExpanded ? "Zwiń kartę" : "Rozwiń kartę", systemImage: isExpanded ? "chevron.up" : "chevron.down")
                    }

                    if role == "admin" {
                        Button(action: onInvite) {
                            Label("Zaproś osobę", systemImage: "person.badge.plus")
                        }
                        .disabled(!space.allowsInvitations)

                        Button(action: onEdit) {
                            Label("Edytuj grupę", systemImage: "pencil")
                        }
                    }

                    Button(role: .destructive, action: onDeleteOrLeave) {
                        Label(role == "admin" ? "Usuń grupę" : "Opuść grupę", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Członkowie")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if members.isEmpty {
                    Text("Nie udało się jeszcze pobrać członków tej grupy.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 10) {
                        OverlappingAvatars(members: members)
                        Text(memberCountLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 8)

                        Button(action: onToggleExpanded) {
                            Label(isExpanded ? "Zwiń" : "Pokaż", systemImage: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if isExpanded {
                Divider()
                    .overlay(Color(.separator))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Osoby w grupie")
                        .font(.subheadline.weight(.semibold))

                    ForEach(members) { member in
                        SpaceMemberRow(member: member)
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(cardBackgroundColor)
        )
        .overlay {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .strokeBorder(cardBorderColor, lineWidth: isSelected ? 2 : 1)
        }
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(cardAccentColor)
                .frame(width: isSelected ? 64 : 42, height: 5)
                .padding(.top, 10)
                .padding(.leading, 16)
        }
        .shadow(color: .black.opacity(isSelected ? 0.14 : 0.08), radius: isSelected ? 14 : 10, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .onTapGesture(perform: onToggleExpanded)
    }

    private var memberCountLabel: String {
        switch members.count {
        case 1:
            return "1 osoba"
        case 2...4:
            return "\(members.count) osoby"
        default:
            return "\(members.count) osób"
        }
    }

    private var spaceTypeLabel: String {
        switch space.type {
        case .shared:
            return "Wspólna"
        case .family:
            return "Rodzinna"
        case .work:
            return "Praca"
        case .private, .personal:
            return "Prywatna"
        }
    }

    private var spaceTypeSymbol: String {
        switch space.type {
        case .shared:
            return "person.2.fill"
        case .family:
            return "house.fill"
        case .work:
            return "briefcase.fill"
        case .private, .personal:
            return "lock.fill"
        }
    }

    private func compactMetaPill(title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2.weight(.bold))
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.16), in: Capsule())
        .fixedSize()
    }

    private func statusBadge(title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.16), in: Capsule())
    }

    private var cardBackgroundColor: Color {
        if isSelected {
            return cardAccentColor.opacity(0.12)
        }
        return Color(.systemBackground)
    }

    private var cardBorderColor: Color {
        if isSelected {
            return cardAccentColor.opacity(0.8)
        }
        return Color(.separator).opacity(0.45)
    }

    private var cardAccentColor: Color {
        switch space.type {
        case .shared:
            return .blue
        case .family:
            return .pink
        case .work:
            return .teal
        case .private, .personal:
            return .orange
        }
    }
}

private struct SpaceMemberRow: View {
    let member: SpaceMemberRecipient

    var body: some View {
        HStack(spacing: 12) {
            SpaceMemberAvatar(member: member)
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(primaryText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                if let secondaryText {
                    Text(secondaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            Text(memberRoleLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground), in: Capsule())
        }
    }

    private var primaryText: String {
        let trimmed = member.fullName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return trimmed
        }
        return member.email
    }

    private var secondaryText: String? {
        let trimmed = member.fullName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }
        return member.email
    }

    private var memberRoleLabel: String {
        switch member.role {
        case "admin":
            return "Admin"
        case "member":
            return "Członek"
        default:
            return member.role.capitalized
        }
    }
}

private struct OverlappingAvatars: View {
    let members: [SpaceMemberRecipient]

    var body: some View {
        HStack(spacing: -12) {
            ForEach(Array(members.prefix(4).enumerated()), id: \.element.id) { index, member in
                SpaceMemberAvatar(member: member)
                    .zIndex(Double(10 - index))
            }

            if members.count > 4 {
                Text("+\(members.count - 4)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .background(Color.white, in: Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
            }
        }
    }
}

private struct SpaceMemberAvatar: View {
    let member: SpaceMemberRecipient

    var body: some View {
        Group {
            if let localURL = AvatarCache.shared.existingURL(userId: member.id, version: 1) {
                AsyncImage(url: localURL) { phase in
                    avatarContent(phase: phase)
                }
            } else if let urlString = member.effectiveAvatarURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    avatarContent(phase: phase)
                }
            } else {
                initialsAvatar
            }
        }
        .frame(width: 38, height: 38)
        .background(Color.white, in: Circle())
        .overlay(Circle().stroke(Color.white, lineWidth: 3))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }

    @ViewBuilder
    private func avatarContent(phase: AsyncImagePhase) -> some View {
        if case .success(let image) = phase {
            image
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            initialsAvatar
        }
    }

    private var initialsAvatar: some View {
        Circle()
            .fill(fallbackColor.gradient)
            .overlay {
                Text(initials)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }
    }

    private var initials: String {
        let base = member.displayName
        let parts = base.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(base.prefix(2)).uppercased()
    }

    private var fallbackColor: Color {
        let colors: [Color] = [.pink, .blue, .green, .orange, .red, .teal]
        let index = abs(member.id.hashValue) % colors.count
        return colors[index]
    }
}

private enum SpacePendingAction: Identifiable {
    case delete(Space, String)
    case leave(Space, String)

    var id: UUID {
        switch self {
        case .delete(let space, _), .leave(let space, _):
            return space.id
        }
    }

    var title: String {
        switch self {
        case .delete(let space, _):
            return "Usunąć grupę \(space.name)?"
        case .leave(let space, _):
            return "Opuścić grupę \(space.name)?"
        }
    }

    var message: String {
        switch self {
        case .delete:
            return "Ta operacja usunie całą przestrzeń dla wszystkich członków."
        case .leave:
            return "Po opuszczeniu grupy stracisz dostęp do jej danych, dopóki ktoś nie zaprosi Cię ponownie."
        }
    }

    var confirmTitle: String {
        switch self {
        case .delete:
            return "Usuń"
        case .leave:
            return "Opuść"
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

    return SpaceListView()
        .environment(authRepo)
        .environment(spaceRepo)
        .environment(authStore)
}
