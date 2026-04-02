#if os(macOS)

import SwiftUI
import SwiftData

private enum MacSidebarItem: String, Hashable, CaseIterable {
    case search
    case home
    case missions
    case notes
    case lists
    case incidents
    case routines
    case budget
    case messages
    case places
    case roles
    case crew
    case spacesManage

    var title: String {
        switch self {
        case .search:
            return "Szukaj"
        case .home:
            return "Home"
        case .missions:
            return "Missions"
        case .notes:
            return "Notes"
        case .lists:
            return "Lists"
        case .incidents:
            return "Incidents"
        case .routines:
            return "Routines"
        case .budget:
            return "Budget"
        case .messages:
            return "Messages"
        case .places:
            return "Places"
        case .roles:
            return "Roles"
        case .crew:
            return "Crew"
        case .spacesManage:
            return "Manage"
        }
    }

    var systemImage: String {
        switch self {
        case .search:
            return "magnifyingglass"
        case .home:
            return "house"
        case .missions:
            return "flag"
        case .notes:
            return "note.text"
        case .lists:
            return "checklist"
        case .incidents:
            return "exclamationmark.triangle"
        case .routines:
            return "repeat"
        case .budget:
            return "creditcard"
        case .messages:
            return "message"
        case .places:
            return "map"
        case .roles:
            return "lock.shield"
        case .crew:
            return "person.2"
        case .spacesManage:
            return "person.3"
        }
    }

    init(tab: TabItem) {
        switch tab {
        case .home:
            self = .home
        case .search:
            self = .search
        case .people:
            self = .crew
        case .spaces:
            self = .spacesManage
        }
    }

    var mappedTab: TabItem {
        switch self {
        case .search:
            return .search
        case .home, .missions, .notes, .lists, .incidents, .routines, .budget:
            return .home
        case .messages, .places, .roles, .crew:
            return .people
        case .spacesManage:
            return .spaces
        }
    }
}

struct MacSidebarShell: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(SpaceRepository.self) private var spaceRepository

    @Binding var selectedTab: TabItem
    @State private var selectedItem: MacSidebarItem
    @State private var presentedSheet: SidebarPresentedSheet?

    init(selectedTab: Binding<TabItem>) {
        _selectedTab = selectedTab
        _selectedItem = State(initialValue: MacSidebarItem(tab: selectedTab.wrappedValue))
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $selectedItem) {
                    Section {
                        sidebarRow(.search)
                    }

                    Section("Browse") {
                        sidebarRow(.home)
                    }

                    Section("Workspace") {
                        sidebarRow(.missions)
                        sidebarRow(.notes)
                        sidebarRow(.lists)
                        sidebarRow(.incidents)
                        sidebarRow(.routines)
                        sidebarRow(.budget)
                    }

                    Section("People") {
                        sidebarRow(.messages)
                        sidebarRow(.places)
                        sidebarRow(.roles)
                        sidebarRow(.crew)
                    }

                    Section("Spaces") {
                        sidebarRow(.spacesManage)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .background(AppTheme.Colors.sidebar)
                .navigationTitle("ufo")
                .frame(minWidth: 260, idealWidth: 280)

                Divider()
                    .overlay(AppTheme.Colors.divider)

                sidebarSpaceSwitcher
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                sidebarProfileFooter
            }
            .background(AppTheme.Colors.sidebar)
        } detail: {
            NavigationStack {
                detailView(for: selectedItem)
                    .appScreenBackground()
            }
        }
        .onChange(of: selectedItem) { _, newValue in
            selectedTab = newValue.mappedTab
        }
        .onChange(of: selectedTab) { _, newValue in
            let mappedItem = MacSidebarItem(tab: newValue)
            if mappedItem != selectedItem {
                selectedItem = mappedItem
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .profile:
                    MacProfileScreen()
                case .settings:
                    MacSettingsScreen()
                }
            }
            .frame(minWidth: 520, minHeight: 520)
        }
    }

    @ViewBuilder
    private func sidebarRow(_ item: MacSidebarItem) -> some View {
        Label(item.title, systemImage: item.systemImage)
            .tag(item)
    }

    @ViewBuilder
    private var sidebarSpaceSwitcher: some View {
        let memberships = authStore.currentUser?.memberships ?? []

        if !memberships.isEmpty {
            Menu {
                ForEach(memberships) { membership in
                    if let space = membership.space {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                spaceRepository.selectedSpace = space
                            }
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(space.name)
                                    Text(space.type.displayName)
                                        .font(.caption)
                                }
                            } icon: {
                                Image(systemName: spaceRepository.selectedSpace?.id == space.id ? "checkmark.circle.fill" : "circle")
                            }
                        }
                    }
                }
            } label: {
                if let selectedSpace = spaceRepository.selectedSpace {
                    MacActiveSpaceMenuButton(space: selectedSpace)
                } else {
                    Label("Wybierz grupę", systemImage: "person.3.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AppTheme.Colors.mutedFill, in: Capsule())
        }
    }

    @ViewBuilder
    private func detailView(for item: MacSidebarItem) -> some View {
        switch item {
        case .search:
            MacSearchScreen()
        case .home:
            MacHomeScreen()
        case .missions:
            MacMissionsScreen()
        case .notes:
            MacNotesScreen()
        case .lists:
            MacListsScreen()
        case .incidents:
            MacIncidentsScreen()
        case .routines:
            MacRoutinesScreen()
        case .budget:
            MacBudgetScreen()
        case .messages:
            MacMessagesScreen()
        case .places:
            MacLocationsScreen()
        case .roles:
            MacRolesScreen()
        case .crew:
            MacCrewScreen()
        case .spacesManage:
            MacSpacesScreen()
        }
    }

    private var sidebarProfileFooter: some View {
        MacSidebarProfileControl(
            user: authStore.currentUser,
            selectedSpaceName: spaceRepository.selectedSpace?.name,
            onOpenProfile: { presentedSheet = .profile },
            onOpenSettings: { presentedSheet = .settings },
            onManageSpaces: { selectedItem = .spacesManage },
            onSignOut: { Task { await authStore.signOut() } }
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private enum SidebarPresentedSheet: String, Identifiable {
    case profile
    case settings

    var id: String { rawValue }
}
#Preview("Sidebar Menu") {
    @Previewable @State var selectedTab: TabItem = .home
    let preview = MainNavigationPreviewFactory.make()

    return MacSidebarShell(selectedTab: $selectedTab)
        .environment(preview.authRepository)
        .environment(preview.spaceRepository)
        .environment(preview.authStore)
        .environment(preview.notificationStore)
        .modelContainer(preview.container)
        .frame(width: 1100, height: 720)
}

#endif
