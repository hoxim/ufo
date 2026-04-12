#if os(iOS)

import SwiftUI
import SwiftData

struct PhoneMissionsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo

    @State private var missionStore: MissionStore?
    @State private var isAddingMission = false
    @State private var editingMission: Mission?
    @State private var viewingMission: Mission?
    @State private var didAutoPresentAdd = false
    @State private var searchText = ""

    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    let autoPresentAdd: Bool

    init(autoPresentAdd: Bool = false) {
        self.autoPresentAdd = autoPresentAdd
    }

    var body: some View {
        Group {
            if let missionStore {
                content(store: missionStore)
            } else {
                ProgressView("missions.list.loading")
            }
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
                PhoneAddMissionView(
                    store: missionStore,
                    userId: authRepo.currentUser?.id,
                    availableOwners: availableOwners,
                    availablePlaces: availablePlaces,
                    availableLists: availableLists,
                    availableNotes: availableNotes,
                    availableIncidents: availableIncidents
                )
                .presentationDetents([.medium, .large])
            }
        }
        .sheet(item: $editingMission) { mission in
            if let missionStore {
                PhoneEditMissionView(
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
            }
        }
        .sheet(item: $viewingMission) { mission in
            PhoneMissionDetailView(
                mission: mission,
                presentationMode: .modal,
                onEdit: {
                    viewingMission = nil
                    DispatchQueue.main.async {
                        editingMission = mission
                    }
                }
            )
            .presentationDetents([.large])
        }
        .task {
            await setupStoreIfNeeded(performRemoteRefresh: !autoPresentAdd)
            if autoPresentAdd && !didAutoPresentAdd && missionStore != nil {
                didAutoPresentAdd = true
                try? await Task.sleep(for: .milliseconds(300))
                isAddingMission = true
            }
        }
        .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
            guard let missionStore else { return }
            missionStore.setSpace(newValue)
            Task { await missionStore.refreshRemote() }
        }
        .safeAreaInset(edge: .bottom) {
            FeatureBottomSearchBar(text: $searchText, prompt: "Search missions")
        }
    }

    @ViewBuilder
    private func content(store: MissionStore) -> some View {
        List {
            if let error = store.lastErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            ForEach(filteredMissions(in: store)) { mission in
                PhoneMissionListRowView(
                    mission: mission,
                    onToggleCompleted: {
                        Task {
                            await store.toggleCompleted(mission, userId: authRepo.currentUser?.id)
                        }
                    },
                    onOpen: {
                        viewingMission = mission
                    },
                    onEdit: {
                        editingMission = mission
                    },
                    onDelete: {
                        Task {
                            await store.deleteMission(mission, userId: authRepo.currentUser?.id)
                        }
                    }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task {
                            await store.deleteMission(mission, userId: authRepo.currentUser?.id)
                        }
                    } label: {
                        Label("common.delete", systemImage: "trash")
                    }

                    Button {
                        editingMission = mission
                    } label: {
                        Label("common.edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }
        .appPrimaryListChrome()
        .refreshable {
            await refreshMissions()
        }
        .overlay {
            if store.isSyncing {
                ProgressView("common.synchronizing")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
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
        if performRemoteRefresh && !isPreview {
            await store.refreshRemote()
        }
    }

    @MainActor
    private func refreshMissions() async {
        await missionStore?.syncPending()
        await missionStore?.refreshRemote()
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
