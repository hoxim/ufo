#if os(iOS)

import SwiftUI
import SwiftData

struct PadMissionsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo

    @State private var missionStore: MissionStore?
    @State private var isAddingMission = false
    @State private var editingMission: Mission?
    @State private var selectedMissionId: UUID?
    @State private var didAutoPresentAdd = false
    @State private var searchText = ""

    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    let autoPresentAdd: Bool

    init(autoPresentAdd: Bool = false) {
        self.autoPresentAdd = autoPresentAdd
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .appScreenBackground()
        .navigationTitle("missions.list.title")
        .hideTabBarIfSupported()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                addMissionToolbarButton
            }
        }
        .sheet(isPresented: $isAddingMission) {
            if let missionStore {
                PadAddMissionView(
                    store: missionStore,
                    userId: authRepo.currentUser?.id,
                    availableOwners: availableOwners,
                    availablePlaces: availablePlaces,
                    availableLists: availableLists,
                    availableNotes: availableNotes,
                    availableIncidents: availableIncidents
                )
                .presentationDetents([.medium, .large])
                .frame(minWidth: 520, minHeight: 520)
            }
        }
        .sheet(item: $editingMission) { mission in
            if let missionStore {
                PadEditMissionView(
                    store: missionStore,
                    mission: mission,
                    userId: authRepo.currentUser?.id,
                    availableOwners: availableOwners,
                    availablePlaces: availablePlaces,
                    availableLists: availableLists,
                    availableNotes: availableNotes,
                    availableIncidents: availableIncidents,
                    initialRelatedListId: linkedChildId(for: mission.id, matching: Set(availableLists.map(\.id))),
                    initialRelatedNoteId: linkedChildId(for: mission.id, matching: Set(availableNotes.map(\.id))),
                    initialRelatedIncidentId: linkedChildId(for: mission.id, matching: Set(availableIncidents.map(\.id)))
                )
                .presentationDetents([.medium, .large])
                .frame(minWidth: 520, minHeight: 520)
            }
        }
        .task {
            await setupStoreIfNeeded(performRemoteRefresh: !autoPresentAdd)
            if autoPresentAdd && !didAutoPresentAdd && missionStore != nil {
                didAutoPresentAdd = true
                try? await Task.sleep(for: .milliseconds(250))
                isAddingMission = true
            }
        }
        .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
            guard let missionStore else { return }
            missionStore.setSpace(newValue)
            selectedMissionId = nil
            Task {
                await missionStore.refreshRemote()
                if selectedMissionId == nil {
                    selectedMissionId = missionStore.missions.first?.id
                }
            }
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        if let missionStore {
            let missions = filteredMissions(in: missionStore)

            VStack(spacing: 0) {
                PadWorkspaceColumnHeader(
                    title: "missions.list.title",
                    selectedSpaceName: spaceRepo.selectedSpace?.name,
                    itemCount: missions.count
                )

                List(selection: $selectedMissionId) {
                    if let error = missionStore.lastErrorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if missions.isEmpty {
                        ContentUnavailableView(
                            "missions.list.empty",
                            systemImage: "flag",
                            description: Text("missions.list.emptyHint")
                        )
                        .frame(maxWidth: .infinity, minHeight: 220)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(missions) { mission in
                            missionSidebarRow(mission)
                                .tag(mission.id)
                                .contextMenu {
                                    Button {
                                        editingMission = mission
                                    } label: {
                                        Label("common.edit", systemImage: "pencil")
                                    }

                                    Button(role: .destructive) {
                                        Task {
                                            await missionStore.deleteMission(mission, userId: authRepo.currentUser?.id)
                                            if selectedMissionId == mission.id {
                                                selectedMissionId = missionStore.missions.first?.id
                                            }
                                        }
                                    } label: {
                                        Label("common.delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                .appPrimaryListChrome()
                .tint(AppTheme.Colors.listSelection)
                .searchable(text: $searchText, prompt: "Search missions")
                .refreshable {
                    await refreshMissions()
                }
            }
        } else {
            ProgressView("missions.list.loading")
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let mission = selectedMission {
            PadMissionDetailView(
                mission: mission,
                presentationMode: .embedded,
                onEdit: {
                    editingMission = mission
                }
            )
        } else if missionStore != nil {
            ContentUnavailableView(
                "Wybierz misję",
                systemImage: "sidebar.left",
                description: Text("Wybierz misję z lewej kolumny, aby zobaczyć szczegóły.")
            )
        } else {
            ProgressView("missions.detail.loading")
        }
    }

    private var selectedMission: Mission? {
        guard let selectedMissionId else { return nil }
        return missionStore?.missions.first(where: { $0.id == selectedMissionId })
    }

    private func missionSidebarRow(_ mission: Mission) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(mission.title)
                .font(.headline)

            if !mission.missionDescription.isEmpty {
                Text(mission.missionDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                Text(mission.priority.localizedLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let place = mission.savedPlaceName, !place.isEmpty {
                    Text(place)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var addMissionToolbarButton: some View {
        Button(action: { isAddingMission = true }) {
            Label("missions.list.action.add", systemImage: "plus")
        }
        .disabled(spaceRepo.selectedSpace == nil || missionStore == nil)
    }

    private func filteredMissions(in store: MissionStore) -> [Mission] {
        let query = normalizedSearchQuery
        guard !query.isEmpty else { return store.missions }

        return store.missions.filter { mission in
            mission.title.localizedCaseInsensitiveContains(query)
                || mission.missionDescription.localizedCaseInsensitiveContains(query)
                || mission.assignees.contains(where: { $0.fullName?.localizedCaseInsensitiveContains(query) ?? false })
                || (mission.savedPlaceName?.localizedCaseInsensitiveContains(query) ?? false)
                || mission.priority.rawValue.localizedCaseInsensitiveContains(query)
        }
    }

    private var normalizedSearchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor
    private func setupStoreIfNeeded(performRemoteRefresh: Bool = true) async {
        guard missionStore == nil else { return }

        let repo = MissionRepository(client: SupabaseConfig.client, context: modelContext)
        let store = MissionStore(modelContext: modelContext, missionRepository: repo)
        missionStore = store

        store.setSpace(spaceRepo.selectedSpace?.id)
        if selectedMissionId == nil {
            selectedMissionId = store.missions.first?.id
        }
        if performRemoteRefresh && !isPreview {
            await store.refreshRemote()
            if selectedMissionId == nil {
                selectedMissionId = store.missions.first?.id
            }
        }
    }

    @MainActor
    private func refreshMissions() async {
        await missionStore?.syncPending()
        await missionStore?.refreshRemote()
        if selectedMissionId == nil {
            selectedMissionId = missionStore?.missions.first?.id
        }
    }

    private var availableOwners: [UserProfile] {
        guard let currentUser = authRepo.currentUser else { return [] }
        let selectedSpaceId = spaceRepo.selectedSpace?.id
        return currentUser.memberships
            .filter { $0.spaceId == selectedSpaceId }
            .compactMap(\.user)
    }

    private var availablePlaces: [SavedPlace] {
        guard let selectedSpaceId = spaceRepo.selectedSpace?.id else { return [] }
        do {
            return try modelContext.fetch(
                FetchDescriptor<SavedPlace>(
                    predicate: #Predicate { $0.spaceId == selectedSpaceId && $0.deletedAt == nil },
                    sortBy: [SortDescriptor(\.name, order: .forward)]
                )
            )
        } catch {
            return []
        }
    }

    private var availableLists: [SharedList] {
        guard let selectedSpaceId = spaceRepo.selectedSpace?.id else { return [] }
        do {
            return try modelContext.fetch(
                FetchDescriptor<SharedList>(
                    predicate: #Predicate { $0.spaceId == selectedSpaceId && $0.deletedAt == nil },
                    sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
                )
            )
        } catch {
            return []
        }
    }

    private var availableNotes: [Note] {
        guard let selectedSpaceId = spaceRepo.selectedSpace?.id else { return [] }
        do {
            return try modelContext.fetch(
                FetchDescriptor<Note>(
                    predicate: #Predicate { $0.spaceId == selectedSpaceId && $0.deletedAt == nil },
                    sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
                )
            )
        } catch {
            return []
        }
    }

    private var availableIncidents: [Incident] {
        guard let selectedSpaceId = spaceRepo.selectedSpace?.id else { return [] }
        do {
            return try modelContext.fetch(
                FetchDescriptor<Incident>(
                    predicate: #Predicate { $0.spaceId == selectedSpaceId && $0.deletedAt == nil },
                    sortBy: [SortDescriptor(\.occurrenceDate, order: .reverse)]
                )
            )
        } catch {
            return []
        }
    }

    private func linkedChildId(for parentId: UUID, matching ids: Set<UUID>) -> UUID? {
        guard let selectedSpaceId = spaceRepo.selectedSpace?.id else { return nil }
        do {
            let links = try modelContext.fetch(
                FetchDescriptor<LinkedThing>(
                    predicate: #Predicate { $0.thingId == selectedSpaceId && $0.parentId == parentId && $0.deletedAt == nil }
                )
            )
            return links.first(where: { ids.contains($0.childId) })?.childId
        } catch {
            return nil
        }
    }
}

struct PadMissionsSidebarWorkspace<Sidebar: View>: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo

    private let sidebar: Sidebar

    @State private var missionStore: MissionStore?
    @State private var isAddingMission = false
    @State private var editingMission: Mission?
    @State private var selectedMissionId: UUID?
    @State private var didAutoPresentAdd = false
    @State private var searchText = ""

    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    let autoPresentAdd: Bool

    init(autoPresentAdd: Bool = false, @ViewBuilder sidebar: () -> Sidebar) {
        self.autoPresentAdd = autoPresentAdd
        self.sidebar = sidebar()
    }

    var body: some View {
        PadSidebarWorkspaceScaffold {
            sidebar
        } content: {
            contentColumn
        } detail: {
            detailColumn
        }
        .sheet(isPresented: $isAddingMission) {
            if let missionStore {
                PadAddMissionView(
                    store: missionStore,
                    userId: authRepo.currentUser?.id,
                    availableOwners: availableOwners,
                    availablePlaces: availablePlaces,
                    availableLists: availableLists,
                    availableNotes: availableNotes,
                    availableIncidents: availableIncidents
                )
                .presentationDetents([.medium, .large])
                .frame(minWidth: 520, minHeight: 520)
            }
        }
        .sheet(item: $editingMission) { mission in
            if let missionStore {
                PadEditMissionView(
                    store: missionStore,
                    mission: mission,
                    userId: authRepo.currentUser?.id,
                    availableOwners: availableOwners,
                    availablePlaces: availablePlaces,
                    availableLists: availableLists,
                    availableNotes: availableNotes,
                    availableIncidents: availableIncidents,
                    initialRelatedListId: linkedChildId(for: mission.id, matching: Set(availableLists.map(\.id))),
                    initialRelatedNoteId: linkedChildId(for: mission.id, matching: Set(availableNotes.map(\.id))),
                    initialRelatedIncidentId: linkedChildId(for: mission.id, matching: Set(availableIncidents.map(\.id)))
                )
                .presentationDetents([.medium, .large])
                .frame(minWidth: 520, minHeight: 520)
            }
        }
        .task {
            await setupStoreIfNeeded(performRemoteRefresh: !autoPresentAdd)
            if autoPresentAdd && !didAutoPresentAdd && missionStore != nil {
                didAutoPresentAdd = true
                try? await Task.sleep(for: .milliseconds(250))
                isAddingMission = true
            }
        }
        .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
            guard let missionStore else { return }
            missionStore.setSpace(newValue)
            selectedMissionId = nil
            Task {
                await missionStore.refreshRemote()
                if selectedMissionId == nil {
                    selectedMissionId = missionStore.missions.first?.id
                }
            }
        }
    }

    @ViewBuilder
    private var contentColumn: some View {
        if let missionStore {
            let missions = filteredMissions(in: missionStore)

            VStack(spacing: 0) {
                List(selection: $selectedMissionId) {
                    if let error = missionStore.lastErrorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if missions.isEmpty {
                        ContentUnavailableView(
                            "missions.list.empty",
                            systemImage: "flag",
                            description: Text("missions.list.emptyHint")
                        )
                        .frame(maxWidth: .infinity, minHeight: 220)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(missions) { mission in
                            missionSidebarRow(mission)
                                .tag(mission.id)
                                .contextMenu {
                                    Button {
                                        editingMission = mission
                                    } label: {
                                        Label("common.edit", systemImage: "pencil")
                                    }

                                    Button(role: .destructive) {
                                        Task {
                                            await missionStore.deleteMission(mission, userId: authRepo.currentUser?.id)
                                            if selectedMissionId == mission.id {
                                                selectedMissionId = missionStore.missions.first?.id
                                            }
                                        }
                                    } label: {
                                        Label("common.delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                .appPrimaryListChrome()
                .tint(AppTheme.Colors.listSelection)
                .searchable(text: $searchText, prompt: "Search missions")
                .refreshable {
                    await refreshMissions()
                }
            }
            .padWorkspaceTopBarTitle("missions.list.title")
            .toolbar {
                ToolbarItem(placement: .platformTopBarTrailing) {
                    addMissionToolbarButton
                }
            }
        } else {
            ProgressView("missions.list.loading")
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let mission = selectedMission {
            PadMissionDetailView(
                mission: mission,
                presentationMode: .embedded,
                onEdit: {
                    editingMission = mission
                },
                showsEmbeddedHeader: false
            )
        } else if missionStore != nil {
            ContentUnavailableView(
                "Wybierz misję",
                systemImage: "sidebar.left",
                description: Text("Wybierz misję z lewej kolumny, aby zobaczyć szczegóły.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ProgressView("missions.detail.loading")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var selectedMission: Mission? {
        guard let selectedMissionId else { return nil }
        return missionStore?.missions.first(where: { $0.id == selectedMissionId })
    }

    private func missionSidebarRow(_ mission: Mission) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(mission.title)
                .font(.headline)

            if !mission.missionDescription.isEmpty {
                Text(mission.missionDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                Text(mission.priority.localizedLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let place = mission.savedPlaceName, !place.isEmpty {
                    Text(place)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var addMissionToolbarButton: some View {
        Button(action: { isAddingMission = true }) {
            Label("missions.list.action.add", systemImage: "plus")
        }
        .disabled(spaceRepo.selectedSpace == nil || missionStore == nil)
    }

    private func filteredMissions(in store: MissionStore) -> [Mission] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.missions }

        return store.missions.filter { mission in
            mission.title.localizedCaseInsensitiveContains(query)
                || mission.missionDescription.localizedCaseInsensitiveContains(query)
                || mission.assignees.contains(where: { $0.fullName?.localizedCaseInsensitiveContains(query) ?? false })
                || (mission.savedPlaceName?.localizedCaseInsensitiveContains(query) ?? false)
                || mission.priority.rawValue.localizedCaseInsensitiveContains(query)
        }
    }

    @MainActor
    private func setupStoreIfNeeded(performRemoteRefresh: Bool = true) async {
        guard missionStore == nil else { return }

        let repo = MissionRepository(client: SupabaseConfig.client, context: modelContext)
        let store = MissionStore(modelContext: modelContext, missionRepository: repo)
        missionStore = store

        store.setSpace(spaceRepo.selectedSpace?.id)
        if selectedMissionId == nil {
            selectedMissionId = store.missions.first?.id
        }
        if performRemoteRefresh && !isPreview {
            await store.refreshRemote()
            if selectedMissionId == nil {
                selectedMissionId = store.missions.first?.id
            }
        }
    }

    @MainActor
    private func refreshMissions() async {
        await missionStore?.syncPending()
        await missionStore?.refreshRemote()
        if selectedMissionId == nil {
            selectedMissionId = missionStore?.missions.first?.id
        }
    }

    private var availableOwners: [UserProfile] {
        guard let currentUser = authRepo.currentUser else { return [] }
        let selectedSpaceId = spaceRepo.selectedSpace?.id
        return currentUser.memberships
            .filter { $0.spaceId == selectedSpaceId }
            .compactMap(\.user)
    }

    private var availablePlaces: [SavedPlace] {
        guard let selectedSpaceId = spaceRepo.selectedSpace?.id else { return [] }
        do {
            return try modelContext.fetch(
                FetchDescriptor<SavedPlace>(
                    predicate: #Predicate { $0.spaceId == selectedSpaceId && $0.deletedAt == nil },
                    sortBy: [SortDescriptor(\.name, order: .forward)]
                )
            )
        } catch {
            return []
        }
    }

    private var availableLists: [SharedList] {
        guard let selectedSpaceId = spaceRepo.selectedSpace?.id else { return [] }
        do {
            return try modelContext.fetch(
                FetchDescriptor<SharedList>(
                    predicate: #Predicate { $0.spaceId == selectedSpaceId && $0.deletedAt == nil },
                    sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
                )
            )
        } catch {
            return []
        }
    }

    private var availableNotes: [Note] {
        guard let selectedSpaceId = spaceRepo.selectedSpace?.id else { return [] }
        do {
            return try modelContext.fetch(
                FetchDescriptor<Note>(
                    predicate: #Predicate { $0.spaceId == selectedSpaceId && $0.deletedAt == nil },
                    sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
                )
            )
        } catch {
            return []
        }
    }

    private var availableIncidents: [Incident] {
        guard let selectedSpaceId = spaceRepo.selectedSpace?.id else { return [] }
        do {
            return try modelContext.fetch(
                FetchDescriptor<Incident>(
                    predicate: #Predicate { $0.spaceId == selectedSpaceId && $0.deletedAt == nil },
                    sortBy: [SortDescriptor(\.occurrenceDate, order: .reverse)]
                )
            )
        } catch {
            return []
        }
    }

    private func linkedChildId(for parentId: UUID, matching ids: Set<UUID>) -> UUID? {
        guard let selectedSpaceId = spaceRepo.selectedSpace?.id else { return nil }
        do {
            let links = try modelContext.fetch(
                FetchDescriptor<LinkedThing>(
                    predicate: #Predicate { $0.thingId == selectedSpaceId && $0.parentId == parentId && $0.deletedAt == nil }
                )
            )
            return links.first(where: { ids.contains($0.childId) })?.childId
        } catch {
            return nil
        }
    }
}

#endif
