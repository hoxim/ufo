#if os(macOS)

import SwiftUI
import SwiftData

struct MacIncidentsScreen: View {
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
        .appScreenBackground()
        .navigationTitle("incidents.list.title")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                addIncidentToolbarButton
            }
        }
        .navigationDestination(isPresented: $isAddingIncident) {
            if let incidentStore {
                MacAddIncidentView(
                    store: incidentStore,
                    userId: authRepo.currentUser?.id,
                    availableMissions: availableMissions,
                    availableLists: availableLists,
                    availablePlaces: availablePlaces
                )
                .frame(minWidth: 520, minHeight: 420)
            }
        }
        .navigationDestination(item: $editingIncident) { incident in
            if let incidentStore {
                MacEditIncidentView(
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
                .frame(minWidth: 520, minHeight: 420)
            }
        }
        .navigationDestination(item: $viewingIncident) { incident in
            MacIncidentDetailView(
                incident: incident,
                presentationMode: .embedded,
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
                try? await Task.sleep(for: .milliseconds(150))
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
    private func content(store: IncidentStore) -> some View {
        List {
            if let error = store.lastErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            ForEach(filteredIncidents(in: store)) { incident in
                incidentRow(incident, store: store)
                    .contextMenu {
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
                    }
            }
        }
        .appPrimaryListChrome()
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

    private func incidentRow(_ incident: Incident, store: IncidentStore) -> some View {
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

#endif
