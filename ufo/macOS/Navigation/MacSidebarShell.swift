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
            return String(localized: "main.tabs.search")
        case .home:
            return String(localized: "main.tabs.home")
        case .missions:
            return String(localized: "navigation.item.missions")
        case .notes:
            return String(localized: "navigation.item.notes")
        case .lists:
            return String(localized: "navigation.item.lists")
        case .incidents:
            return String(localized: "navigation.item.incidents")
        case .routines:
            return String(localized: "navigation.item.routines")
        case .budget:
            return String(localized: "main.tabs.budget")
        case .messages:
            return String(localized: "navigation.item.messages")
        case .places:
            return String(localized: "navigation.item.places")
        case .roles:
            return String(localized: "navigation.item.roles")
        case .crew:
            return String(localized: "navigation.item.crew")
        case .spacesManage:
            return String(localized: "navigation.item.manage")
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

    var accentColor: Color {
        switch self {
        case .search:
            return AppTheme.FeatureColors.searchAccent
        case .home:
            return AppTheme.FeatureColors.homeAccent
        case .missions:
            return AppTheme.FeatureColors.missionsAccent
        case .notes:
            return AppTheme.FeatureColors.notesAccent
        case .lists:
            return AppTheme.FeatureColors.listsAccent
        case .incidents:
            return AppTheme.FeatureColors.incidentsAccent
        case .routines:
            return AppTheme.FeatureColors.routinesAccent
        case .budget:
            return AppTheme.FeatureColors.budgetAccent
        case .messages:
            return AppTheme.FeatureColors.messagesAccent
        case .places:
            return AppTheme.FeatureColors.locationsAccent
        case .roles:
            return AppTheme.FeatureColors.rolesAccent
        case .crew:
            return AppTheme.FeatureColors.peopleAccent
        case .spacesManage:
            return AppTheme.FeatureColors.spacesAccent
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

                    Section("navigation.section.browse") {
                        sidebarRow(.home)
                    }

                    Section("navigation.section.workspace") {
                        sidebarRow(.notes)
                        sidebarRow(.missions)
                        sidebarRow(.lists)
                        sidebarRow(.incidents)
                        sidebarRow(.routines)
                        sidebarRow(.budget)
                    }

                    Section("navigation.section.people") {
                        sidebarRow(.messages)
                        sidebarRow(.places)
                        sidebarRow(.roles)
                        sidebarRow(.crew)
                    }

                    Section("navigation.section.spaces") {
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
        HStack(spacing: 12) {
            Image(systemName: item.systemImage)
                .frame(width: 20)
                .foregroundStyle(item.accentColor)

            Text(item.title)
                .foregroundStyle(.primary)

            Spacer()
        }
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
                                    .foregroundStyle(AppTheme.FeatureColors.spacesAccent)
                            }
                        }
                    }
                }
            } label: {
                if let selectedSpace = spaceRepository.selectedSpace {
                    MacActiveSpaceMenuButton(space: selectedSpace)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "person.3.fill")
                            .foregroundStyle(AppTheme.FeatureColors.spacesAccent)
                        Text("spaces.selector.choose")
                    }
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
