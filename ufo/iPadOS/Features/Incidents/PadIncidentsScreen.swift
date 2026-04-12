#if os(iOS)

import SwiftUI
import SwiftData

struct PadIncidentsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo

    @State private var incidentStore: IncidentStore?
    @State private var isAddingIncident = false
    @State private var editingIncident: Incident?
    @State private var selectedIncidentId: UUID?
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
        .navigationTitle("incidents.list.title")
        .navigationBarTitleDisplayMode(.large)
        .hideTabBarIfSupported()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                addIncidentToolbarButton
            }
        }
        .sheet(isPresented: $isAddingIncident) {
            if let incidentStore {
                PadAddIncidentView(
                    store: incidentStore,
                    userId: authRepo.currentUser?.id,
                    availableMissions: availableMissions,
                    availableLists: availableLists,
                    availablePlaces: availablePlaces
                )
                .presentationDetents([.medium, .large])
                .frame(minWidth: 520, minHeight: 420)
            }
        }
        .sheet(item: $editingIncident) { incident in
            if let incidentStore {
                PadEditIncidentView(
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
                .presentationDetents([.medium, .large])
                .frame(minWidth: 520, minHeight: 420)
            }
        }
        .task {
            await setupStoreIfNeeded(performRemoteRefresh: !autoPresentAdd)
            if autoPresentAdd && !didAutoPresentAdd && incidentStore != nil {
                didAutoPresentAdd = true
                try? await Task.sleep(for: .milliseconds(250))
                isAddingIncident = true
            }
        }
        .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
            guard let incidentStore else { return }
            incidentStore.setSpace(newValue)
            selectedIncidentId = nil
            Task {
                await incidentStore.refreshRemote()
                if selectedIncidentId == nil {
                    selectedIncidentId = incidentStore.incidents.first?.id
                }
            }
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        if let incidentStore {
            let incidents = filteredIncidents(in: incidentStore)

            VStack(spacing: 0) {
                PadWorkspaceColumnHeader(
                    title: "incidents.list.title",
                    selectedSpaceName: spaceRepo.selectedSpace?.name,
                    itemCount: incidents.count
                )

                List(selection: $selectedIncidentId) {
                    if let error = incidentStore.lastErrorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if incidents.isEmpty {
                        ContentUnavailableView(
                            "incidents.list.empty",
                            systemImage: "exclamationmark.triangle",
                            description: Text("incidents.list.emptyHint")
                        )
                        .frame(maxWidth: .infinity, minHeight: 220)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(incidents) { incident in
                            incidentSidebarRow(incident)
                                .tag(incident.id)
                                .contextMenu {
                                    Button {
                                        editingIncident = incident
                                    } label: {
                                        Label("common.edit", systemImage: "pencil")
                                    }

                                    Button(role: .destructive) {
                                        Task {
                                            await incidentStore.deleteIncident(incident, userId: authRepo.currentUser?.id)
                                            if selectedIncidentId == incident.id {
                                                selectedIncidentId = incidentStore.incidents.first?.id
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
                .searchable(text: $searchText, prompt: "Search incidents")
                .refreshable {
                    await refreshIncidents()
                }
            }
        } else {
            ProgressView("incidents.list.loading")
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let incident = selectedIncident {
            PadIncidentDetailView(
                incident: incident,
                presentationMode: .embedded,
                onEdit: {
                    editingIncident = incident
                }
            )
        } else if incidentStore != nil {
            ContentUnavailableView(
                "Wybierz incydent",
                systemImage: "sidebar.left",
                description: Text("Wybierz incydent z lewej kolumny, aby zobaczyć szczegóły.")
            )
        } else {
            ProgressView("incidents.detail.loading")
        }
    }

    private var selectedIncident: Incident? {
        guard let selectedIncidentId else { return nil }
        return incidentStore?.incidents.first(where: { $0.id == selectedIncidentId })
    }

    private func incidentSidebarRow(_ incident: Incident) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if let iconName = incident.iconName, !iconName.isEmpty {
                Image(systemName: iconName)
                    .foregroundStyle(Color(hex: incident.iconColorHex ?? "#F59E0B"))
                    .frame(width: 24)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(incident.title)
                    .font(.headline)

                if let description = incident.incidentDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(incident.occurrenceDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("\(incident.severity.localizedLabel) · \(incident.status.localizedLabel)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func filteredIncidents(in store: IncidentStore) -> [Incident] {
        let query = normalizedSearchQuery
        guard !query.isEmpty else { return store.incidents }

        return store.incidents.filter { incident in
            incident.title.localizedCaseInsensitiveContains(query)
                || (incident.incidentDescription?.localizedCaseInsensitiveContains(query) ?? false)
                || incident.severity.rawValue.localizedCaseInsensitiveContains(query)
                || incident.status.rawValue.localizedCaseInsensitiveContains(query)
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
        if selectedIncidentId == nil {
            selectedIncidentId = store.incidents.first?.id
        }
        if performRemoteRefresh && !isPreview {
            await store.refreshRemote()
            if selectedIncidentId == nil {
                selectedIncidentId = store.incidents.first?.id
            }
        }
    }

    @MainActor
    private func refreshIncidents() async {
        await incidentStore?.syncPending()
        await incidentStore?.refreshRemote()
        if selectedIncidentId == nil {
            selectedIncidentId = incidentStore?.incidents.first?.id
        }
    }
}

struct PadIncidentsSidebarWorkspace<Sidebar: View>: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo

    private let sidebar: Sidebar

    @State private var incidentStore: IncidentStore?
    @State private var isAddingIncident = false
    @State private var editingIncident: Incident?
    @State private var selectedIncidentId: UUID?
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
        .sheet(isPresented: $isAddingIncident) {
            if let incidentStore {
                PadAddIncidentView(
                    store: incidentStore,
                    userId: authRepo.currentUser?.id,
                    availableMissions: availableMissions,
                    availableLists: availableLists,
                    availablePlaces: availablePlaces
                )
                .presentationDetents([.medium, .large])
                .frame(minWidth: 520, minHeight: 420)
            }
        }
        .sheet(item: $editingIncident) { incident in
            if let incidentStore {
                PadEditIncidentView(
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
                .presentationDetents([.medium, .large])
                .frame(minWidth: 520, minHeight: 420)
            }
        }
        .task {
            await setupStoreIfNeeded(performRemoteRefresh: !autoPresentAdd)
            if autoPresentAdd && !didAutoPresentAdd && incidentStore != nil {
                didAutoPresentAdd = true
                try? await Task.sleep(for: .milliseconds(250))
                isAddingIncident = true
            }
        }
        .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
            guard let incidentStore else { return }
            incidentStore.setSpace(newValue)
            selectedIncidentId = nil
            Task {
                await incidentStore.refreshRemote()
                if selectedIncidentId == nil {
                    selectedIncidentId = incidentStore.incidents.first?.id
                }
            }
        }
    }

    @ViewBuilder
    private var contentColumn: some View {
        if let incidentStore {
            let incidents = filteredIncidents(in: incidentStore)

            VStack(spacing: 0) {
                List(selection: $selectedIncidentId) {
                    if let error = incidentStore.lastErrorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if incidents.isEmpty {
                        ContentUnavailableView(
                            "incidents.list.empty",
                            systemImage: "exclamationmark.triangle",
                            description: Text("incidents.list.emptyHint")
                        )
                        .frame(maxWidth: .infinity, minHeight: 220)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(incidents) { incident in
                            incidentSidebarRow(incident)
                                .tag(incident.id)
                                .contextMenu {
                                    Button {
                                        editingIncident = incident
                                    } label: {
                                        Label("common.edit", systemImage: "pencil")
                                    }

                                    Button(role: .destructive) {
                                        Task {
                                            await incidentStore.deleteIncident(incident, userId: authRepo.currentUser?.id)
                                            if selectedIncidentId == incident.id {
                                                selectedIncidentId = incidentStore.incidents.first?.id
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
                .searchable(text: $searchText, prompt: "Search incidents")
                .refreshable {
                    await refreshIncidents()
                }
            }
            .padWorkspaceTopBarTitle("incidents.list.title")
            .toolbar {
                ToolbarItem(placement: .platformTopBarTrailing) {
                    addIncidentToolbarButton
                }
            }
        } else {
            ProgressView("incidents.list.loading")
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let incident = selectedIncident {
            PadIncidentDetailView(
                incident: incident,
                presentationMode: .embedded,
                onEdit: {
                    editingIncident = incident
                },
                showsEmbeddedHeader: false
            )
        } else if incidentStore != nil {
            ContentUnavailableView(
                "Wybierz incydent",
                systemImage: "sidebar.left",
                description: Text("Wybierz incydent z lewej kolumny, aby zobaczyć szczegóły.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ProgressView("incidents.detail.loading")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var selectedIncident: Incident? {
        guard let selectedIncidentId else { return nil }
        return incidentStore?.incidents.first(where: { $0.id == selectedIncidentId })
    }

    private func incidentSidebarRow(_ incident: Incident) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if let iconName = incident.iconName, !iconName.isEmpty {
                Image(systemName: iconName)
                    .foregroundStyle(Color(hex: incident.iconColorHex ?? "#F59E0B"))
                    .frame(width: 24)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(incident.title)
                    .font(.headline)

                if let description = incident.incidentDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(incident.occurrenceDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("\(incident.severity.localizedLabel) · \(incident.status.localizedLabel)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func filteredIncidents(in store: IncidentStore) -> [Incident] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.incidents }

        return store.incidents.filter { incident in
            incident.title.localizedCaseInsensitiveContains(query)
                || (incident.incidentDescription?.localizedCaseInsensitiveContains(query) ?? false)
                || incident.severity.rawValue.localizedCaseInsensitiveContains(query)
                || incident.status.rawValue.localizedCaseInsensitiveContains(query)
        }
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
        if selectedIncidentId == nil {
            selectedIncidentId = store.incidents.first?.id
        }
        if performRemoteRefresh && !isPreview {
            await store.refreshRemote()
            if selectedIncidentId == nil {
                selectedIncidentId = store.incidents.first?.id
            }
        }
    }

    @MainActor
    private func refreshIncidents() async {
        await incidentStore?.syncPending()
        await incidentStore?.refreshRemote()
        if selectedIncidentId == nil {
            selectedIncidentId = incidentStore?.incidents.first?.id
        }
    }
}

#endif
