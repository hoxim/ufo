import SwiftUI

#if os(macOS)

struct MacSidebarProfileControl: View {
    let user: UserProfile?
    let selectedSpaceName: String?
    let onOpenProfile: () -> Void
    let onOpenSettings: () -> Void
    let onManageSpaces: () -> Void
    let onSignOut: () -> Void

    @State private var isPopoverPresented = false

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 8) {
                AvatarCircle(user: user, size: 18)

                Text(user?.effectiveDisplayName ?? user?.email ?? "Profile")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

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
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    AvatarCircle(user: user, size: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(user?.effectiveDisplayName ?? user?.email ?? "Profile")
                            .font(.subheadline.weight(.semibold))

                        if let selectedSpaceName, !selectedSpaceName.isEmpty {
                            Text(selectedSpaceName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(14)

                Divider()

                menuButton("Profile", systemImage: "person.crop.circle") {
                    onOpenProfile()
                }

                menuButton("Settings", systemImage: "gearshape") {
                    onOpenSettings()
                }

                menuButton("Manage spaces", systemImage: "person.3") {
                    onManageSpaces()
                }

                Divider()

                menuButton("Sign out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                    onSignOut()
                }
            }
            .frame(width: 240)
            .background(AppTheme.Colors.surface)
        }
    }

    private func menuButton(
        _ title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role) {
            isPopoverPresented = false
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

#endif
