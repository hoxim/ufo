#if os(iOS)

import SwiftUI

struct PadSidebarProfileControl: View {
    let user: UserProfile?
    let selectedSpaceName: String?
    let onOpenProfile: () -> Void
    let onOpenSettings: () -> Void
    let onManageSpaces: () -> Void
    let onSignOut: () -> Void

    @State private var isMenuPresented = false

    var body: some View {
        Button {
            isMenuPresented = true
        } label: {
            HStack(spacing: 8) {
                AvatarCircle(user: user, size: 18)

                Text(user?.effectiveDisplayName ?? user?.email ?? String(localized: "navigation.action.profile"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 22)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background(AppTheme.Colors.mutedFill, in: Capsule())
        .confirmationDialog(
            user?.effectiveDisplayName ?? user?.email ?? String(localized: "navigation.action.profile"),
            isPresented: $isMenuPresented,
            titleVisibility: .visible
        ) {
            Button(String(localized: "navigation.action.profile")) {
                onOpenProfile()
            }

            Button(String(localized: "navigation.action.settings")) {
                onOpenSettings()
            }

            Button(String(localized: "navigation.action.manageSpaces")) {
                onManageSpaces()
            }

            Button(String(localized: "navigation.action.signOut"), role: .destructive) {
                onSignOut()
            }
        } message: {
            if let selectedSpaceName, !selectedSpaceName.isEmpty {
                Text(selectedSpaceName)
            }
        }
    }
}

#endif
