#if os(iOS)

import SwiftUI

struct PhoneSpaceCard: View {
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
                            statusBadge(title: String(localized: "spaces.card.active"), tint: .green)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Label("spaces.card.info", systemImage: "info.circle")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: infoColumns, alignment: .leading, spacing: 8) {
                            compactMetaPill(
                                title: space.inviteCode,
                                icon: "number",
                                tint: .secondary
                            )
                            compactMetaPill(
                                title: role == "admin" ? String(localized: "spaces.card.role.owner") : String(localized: "spaces.card.role.guest"),
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
                        Label("spaces.card.action.select", systemImage: "checkmark.circle")
                    }

                    Button(action: onToggleExpanded) {
                        Label(isExpanded ? String(localized: "spaces.card.action.collapse") : String(localized: "spaces.card.action.expand"), systemImage: isExpanded ? "chevron.up" : "chevron.down")
                    }

                    if role == "admin" {
                        Button(action: onInvite) {
                            Label("spaces.card.action.invite", systemImage: "person.badge.plus")
                        }
                        .disabled(!space.allowsInvitations)

                        Button(action: onEdit) {
                            Label("spaces.card.action.edit", systemImage: "pencil")
                        }
                    }

                    Button(role: .destructive, action: onDeleteOrLeave) {
                        Label(role == "admin" ? String(localized: "spaces.card.action.delete") : String(localized: "spaces.card.action.leave"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("spaces.card.members")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if members.isEmpty {
                    Text("spaces.card.membersUnavailable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 10) {
                        PhoneOverlappingAvatars(members: members)
                        Text(memberCountLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 8)

                        Button(action: onToggleExpanded) {
                            Label(isExpanded ? String(localized: "spaces.card.action.hide") : String(localized: "spaces.card.action.show"), systemImage: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if isExpanded {
                Divider()
                    .overlay(Color.separatorAdaptive)

                VStack(alignment: .leading, spacing: 12) {
                    Text("spaces.card.memberList")
                        .font(.subheadline.weight(.semibold))

                    ForEach(members) { member in
                        PhoneSpaceMemberRow(member: member)
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
        String(format: String(localized: "spaces.card.memberCount"), members.count)
    }

    private var spaceTypeLabel: String {
        switch space.type {
        case .shared:
            return String(localized: "spaces.type.shared")
        case .family:
            return String(localized: "spaces.type.family")
        case .work:
            return String(localized: "spaces.type.work")
        case .private, .personal:
            return String(localized: "spaces.type.private")
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
        return .systemBackground
    }

    private var cardBorderColor: Color {
        if isSelected {
            return cardAccentColor.opacity(0.8)
        }
        return Color.separatorAdaptive.opacity(0.45)
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

struct PhoneSpaceMemberRow: View {
    let member: SpaceMemberRecipient

    var body: some View {
        HStack(spacing: 12) {
            PhoneSpaceMemberAvatar(member: member)
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
                .background(Color.secondarySystemBackgroundAdaptive, in: Capsule())
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
            return String(localized: "spaces.member.role.admin")
        case "member":
            return String(localized: "spaces.member.role.member")
        default:
            return member.role.capitalized
        }
    }
}

struct PhoneOverlappingAvatars: View {
    let members: [SpaceMemberRecipient]

    var body: some View {
        HStack(spacing: -12) {
            ForEach(Array(members.prefix(4).enumerated()), id: \.element.id) { index, member in
                PhoneSpaceMemberAvatar(member: member)
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

struct PhoneSpaceMemberAvatar: View {
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

#Preview("Phone Space Card") {
    let space = Space(id: UUID(), name: "Family Crew", inviteCode: "UFO123", category: SpaceType.family.rawValue)
    let members = [
        SpaceMemberRecipient(
            id: UUID(),
            email: "preview@ufo.app",
            fullName: "Preview User",
            avatarURL: nil,
            providerAvatarURL: nil,
            role: "admin"
        ),
        SpaceMemberRecipient(
            id: UUID(),
            email: "alex@ufo.app",
            fullName: "Alex",
            avatarURL: nil,
            providerAvatarURL: nil,
            role: "member"
        )
    ]

    PhoneSpaceCard(
        space: space,
        role: "admin",
        isSelected: true,
        isExpanded: true,
        members: members,
        onSelect: {},
        onToggleExpanded: {},
        onInvite: {},
        onEdit: {},
        onDeleteOrLeave: {}
    )
    .padding()
}

#endif
