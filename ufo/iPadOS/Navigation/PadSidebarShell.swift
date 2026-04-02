#if os(iOS)

import SwiftUI
import SwiftData

private enum PadSidebarItem: String, Hashable, CaseIterable {
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

private enum PadSidebarPresentedSheet: String, Identifiable {
    case profile
    case settings

    var id: String { rawValue }
}

struct PadSidebarShell: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(SpaceRepository.self) private var spaceRepository

    @Binding var selectedTab: TabItem
    @State private var selectedItem: PadSidebarItem
    @State private var presentedSheet: PadSidebarPresentedSheet?

    init(selectedTab: Binding<TabItem>) {
        _selectedTab = selectedTab
        _selectedItem = State(initialValue: PadSidebarItem(tab: selectedTab.wrappedValue))
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List {
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
                .navigationTitle("ufo")

                Divider()

                sidebarFooter
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
        } detail: {
            NavigationStack {
                detailView(for: selectedItem)
                    .appScreenBackground()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: selectedItem) { _, newValue in
            selectedTab = newValue.mappedTab
        }
        .onChange(of: selectedTab) { _, newValue in
            let mappedItem = PadSidebarItem(tab: newValue)
            if mappedItem != selectedItem {
                selectedItem = mappedItem
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .profile:
                    PadProfileScreen()
                case .settings:
                    PadSettingsScreen()
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private func sidebarRow(_ item: PadSidebarItem) -> some View {
        Button {
            selectedItem = item
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.systemImage)
                    .frame(width: 20)

                Text(item.title)

                Spacer()
            }
            .font(.body)
            .foregroundStyle(selectedItem == item ? .white : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(selectionBackground(for: item))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func detailView(for item: PadSidebarItem) -> some View {
        switch item {
        case .search:
            PadSearchScreen()
        case .home:
            PadHomeScreen()
        case .missions:
            PadMissionsScreen()
        case .notes:
            PadNotesScreen()
        case .lists:
            PadListsScreen()
        case .incidents:
            PadIncidentsScreen()
        case .routines:
            PadRoutinesScreen()
        case .budget:
            PadBudgetScreen()
        case .messages:
            PadMessagesScreen()
        case .places:
            PadLocationsScreen()
        case .roles:
            PadRolesScreen()
        case .crew:
            PadPeopleScreen(displayMode: .crew)
        case .spacesManage:
            PadSpacesScreen()
        }
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            sidebarSpaceSwitcher

            HStack(spacing: 10) {
                Button {
                    presentedSheet = .profile
                } label: {
                    Label("Profil", systemImage: "person.crop.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    presentedSheet = .settings
                } label: {
                    Label("Ustawienia", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private func selectionBackground(for item: PadSidebarItem) -> some View {
        if selectedItem == item {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor)
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.clear)
        }
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
                            Label(space.name, systemImage: spaceRepository.selectedSpace?.id == space.id ? "checkmark.circle.fill" : "circle")
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "person.3.fill")
                    Text(spaceRepository.selectedSpace?.name ?? "Wybierz grupę")
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview("iPad Sidebar") {
    @Previewable @State var selectedTab: TabItem = .home
    let preview = MainNavigationPreviewFactory.make()

    return PadSidebarShell(selectedTab: $selectedTab)
        .environment(preview.authRepository)
        .environment(preview.spaceRepository)
        .environment(preview.authStore)
        .environment(preview.notificationStore)
        .environment(AppPreferences.shared)
        .modelContainer(preview.container)
}

#endif
