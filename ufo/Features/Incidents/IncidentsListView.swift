import SwiftUI
import SwiftData

struct IncidentsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo

    @State private var incidentStore: IncidentStore?
    @State private var isAddingIncident = false
    @State private var editingIncident: Incident?
    @State private var viewingIncident: Incident?
    @State private var didAutoPresentAdd = false
    @State private var searchText = ""
    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    let autoPresentAdd: Bool

    init(autoPresentAdd: Bool = false) {
        self.autoPresentAdd = autoPresentAdd
    }

    var body: some View {
        Group {
            if let incidentStore {
                content(store: incidentStore)
            } else {
                ProgressView("incidents.list.loading")
            }
        }
        .navigationTitle("incidents.list.title")
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                addIncidentToolbarButton
            }
        }
        .sheet(isPresented: $isAddingIncident) {
            if let incidentStore {
                AddIncidentView(
                    store: incidentStore,
                    userId: authRepo.currentUser?.id,
                    availableMissions: availableMissions,
                    availableLists: availableLists,
                    availablePlaces: availablePlaces
                )
                #if os(iOS)
                .presentationDetents([.medium, .large])
                #endif
                #if os(macOS)
                .frame(minWidth: 520, minHeight: 420)
                #endif
            }
        }
        .sheet(item: $editingIncident) { incident in
            if let incidentStore {
                EditIncidentView(
                    store: incidentStore,
                    incident: incident,
                    userId: authRepo.currentUser?.id,
                    availableMissions: availableMissions,
                    availableLists: availableLists,
                    availablePlaces: availablePlaces,
                    initialRelatedMissionId: linkedChildId(for: incident.id, matching: Set(availableMissions.map(\.id))),
                    initialRelatedListId: linkedChildId(for: incident.id, matching: Set(availableLists.map(\.id))),
                    initialRelatedPlaceId: linkedChildId(for: incident.id, matching: Set(availablePlaces.map(\.id)))
                )
                #if os(iOS)
                .presentationDetents([.medium, .large])
                #endif
                #if os(macOS)
                .frame(minWidth: 520, minHeight: 420)
                #endif
            }
        }
        .sheet(item: $viewingIncident) { incident in
            IncidentDetailView(
                incident: incident,
                onEdit: {
                    viewingIncident = nil
                    DispatchQueue.main.async {
                        editingIncident = incident
                    }
                }
            )
        }
        .task {
            await setupStoreIfNeeded(performRemoteRefresh: !autoPresentAdd)
            if autoPresentAdd && !didAutoPresentAdd && incidentStore != nil {
                didAutoPresentAdd = true
                try? await Task.sleep(for: .milliseconds(300))
                isAddingIncident = true
            }
        }
        .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
            guard let incidentStore else { return }
            incidentStore.setSpace(newValue)
            Task { await incidentStore.refreshRemote() }
        }
        .safeAreaInset(edge: .bottom) {
            FeatureBottomSearchBar(text: $searchText, prompt: "Search incidents")
        }
    }

    @ViewBuilder
    /// Handles content.
    private func content(store: IncidentStore) -> some View {
        List {
            if let error = store.lastErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            ForEach(filteredIncidents(in: store)) { incident in
                HStack {
                    Button {
                        viewingIncident = incident
                    } label: {
                        HStack {
                            if let iconName = incident.iconName, !iconName.isEmpty {
                                Image(systemName: iconName)
                                    .foregroundStyle(Color(hex: incident.iconColorHex ?? "#F59E0B"))
                            }
                            VStack(alignment: .leading) {
                                Text(incident.title)
                                    .font(.headline)

                                if let description = incident.incidentDescription, !description.isEmpty {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Text(incident.occurrenceDate.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("\(IncidentSeverity(rawValue: incident.resolvedSeverity)?.localizedLabel ?? incident.resolvedSeverity.capitalized) · \(IncidentStatus(rawValue: incident.resolvedStatus)?.localizedLabel ?? incident.resolvedStatus.capitalized)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if let cost = incident.cost {
                                    Text(cost.formatted(.currency(code: "PLN")))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                if incident.imageData != nil {
                                    Text("common.imageAttached")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Menu {
                        Button {
                            editingIncident = incident
                        } label: {
                            Label("common.edit", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            Task {
                                await store.deleteIncident(incident, userId: authRepo.currentUser?.id)
                            }
                        } label: {
                            Label("common.delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .refreshable {
            await refreshIncidents()
        }
        .overlay {
            if store.isSyncing {
                ProgressView("common.synchronizing")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func filteredIncidents(in store: IncidentStore) -> [Incident] {
        let query = normalizedSearchQuery
        guard !query.isEmpty else { return store.incidents }

        return store.incidents.filter { incident in
            incident.title.localizedCaseInsensitiveContains(query)
                || (incident.incidentDescription?.localizedCaseInsensitiveContains(query) ?? false)
                || incident.resolvedSeverity.localizedCaseInsensitiveContains(query)
                || incident.resolvedStatus.localizedCaseInsensitiveContains(query)
        }
    }

    private var normalizedSearchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var addIncidentToolbarButton: some View {
        Button {
            isAddingIncident = true
        } label: {
            Label("incidents.list.action.add", systemImage: "plus")
        }
        .disabled(spaceRepo.selectedSpace == nil || incidentStore == nil)
    }

    private var availableMissions: [Mission] {
        guard let selectedSpaceId = spaceRepo.selectedSpace?.id else { return [] }
        do {
            return try modelContext.fetch(
                FetchDescriptor<Mission>(
                    predicate: #Predicate { $0.spaceId == selectedSpaceId && $0.deletedAt == nil },
                    sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
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

    @MainActor
    /// Sets up store if needed.
    private func setupStoreIfNeeded(performRemoteRefresh: Bool = true) async {
        guard incidentStore == nil else { return }

        let repo = IncidentRepository(client: SupabaseConfig.client, context: modelContext)
        let store = IncidentStore(modelContext: modelContext, repository: repo)
        incidentStore = store

        store.setSpace(spaceRepo.selectedSpace?.id)
        if performRemoteRefresh && !isPreview {
            await store.refreshRemote()
        }
    }

    @MainActor
    private func refreshIncidents() async {
        await incidentStore?.syncPending()
        await incidentStore?.refreshRemote()
    }
}

#Preview("incidents.list.title") {
    let schema = Schema([
        UserProfile.self,
        Space.self,
        SpaceMembership.self,
        SpaceInvitation.self,
        Mission.self,
        Incident.self,
        LinkedThing.self,
        Assignment.self
    ])
    let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))

    let context = container.mainContext
    let user = UserProfile(id: UUID(), email: "preview@ufo.app", fullName: "Preview User", role: "admin")
    context.insert(user)

    let space = Space(id: UUID(), name: "Family Crew", inviteCode: "UFO123")
    context.insert(space)
    context.insert(SpaceMembership(user: user, space: space, role: "admin"))

    context.insert(Incident(spaceId: space.id, title: "Late return", incidentDescription: "School trip", occurrenceDate: .now, createdBy: user.id))
    do {
        try context.save()
    } catch {
        Log.dbError("Incidents preview context.save", error)
    }

    let authRepo = AuthRepository(client: SupabaseConfig.client, isLoggedIn: true, currentUser: user)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    spaceRepo.selectedSpace = space

    return IncidentsListView()
        .environment(authRepo)
        .environment(spaceRepo)
        .modelContainer(container)
}
