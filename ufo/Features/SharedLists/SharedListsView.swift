import SwiftUI
import SwiftData

struct SharedListsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo

    @State private var listStore: SharedListStore?
    @State private var isAddingList = false
    @State private var selectedListId: UUID?
    @State private var didAutoPresentAdd = false
    @State private var searchText = ""

    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    let autoPresentAdd: Bool

    init(autoPresentAdd: Bool = false) {
        self.autoPresentAdd = autoPresentAdd
    }

    var body: some View {
        Group {
            if let store = listStore {
                content(store: store)
            } else {
                ProgressView("lists.view.loading")
            }
        }
        .appScreenBackground()
        .navigationTitle("lists.view.title")
        .hideTabBarIfSupported()
        .navigationDestination(item: $selectedListId) { listId in
            detailDestination(for: listId)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingList = true
                } label: {
                    Label("lists.view.action.add", systemImage: "plus")
                }
                .disabled(spaceRepo.selectedSpace == nil || listStore == nil)
            }
        }
        .adaptiveFormPresentation(isPresented: $isAddingList) {
            if let listStore {
                AddSharedListView(
                    store: listStore,
                    actorId: authRepo.currentUser?.id,
                    availablePlaces: availablePlaces()
                ) { createdListId in
                    selectedListId = createdListId
                }
                #if os(iOS)
                .presentationDetents([.medium, .large])
                #endif
                #if os(macOS)
                .frame(minWidth: 560, minHeight: 520)
                #endif
            }
        }
        .task {
            Log.msg("SharedListsView.task start. autoPresentAdd=\(autoPresentAdd) selectedSpace=\(spaceRepo.selectedSpace?.id.uuidString ?? "nil")")
            await setupStoreIfNeeded(performRemoteRefresh: !autoPresentAdd)
            if autoPresentAdd && !didAutoPresentAdd && listStore != nil {
                didAutoPresentAdd = true
                try? await Task.sleep(for: .milliseconds(300))
                isAddingList = true
            }
        }
        .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
            Log.msg("SharedListsView selected space changed to \(newValue?.uuidString ?? "nil")")
            listStore?.setSpace(newValue)
            selectedListId = nil
            Task { await listStore?.refreshRemote() }
        }
        .safeAreaInset(edge: .bottom) {
            FeatureBottomSearchBar(text: $searchText, prompt: "Search lists")
        }
    }

    @ViewBuilder
    /// Renders main list content.
    private func content(store: SharedListStore) -> some View {
        let lists = filteredLists(in: store)

        if lists.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("lists.view.empty")
                    .font(.headline)
                Text("lists.view.emptyHint")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                if let error = store.lastErrorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                ForEach(lists) { list in
                    Button {
                        selectedListId = list.id
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: list.iconName ?? "checklist")
                                .foregroundStyle(Color(hex: list.iconColorHex ?? "#6366F1"))
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(list.name)
                                    .font(.headline)
                                Text(list.type.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let savedPlaceName = list.savedPlaceName, !savedPlaceName.isEmpty {
                                    Text(savedPlaceName)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            let count = store.itemsByList[list.id]?.count ?? 0
                            Text("\(count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        Log.msg("Opening shared list detail. listId=\(list.id.uuidString) name=\(list.name) items=\(store.itemsByList[list.id]?.count ?? 0)")
                    })
                }
            }
            .appPrimaryListChrome()
            .refreshable {
                await refreshLists()
            }
        }
    }

    private func filteredLists(in store: SharedListStore) -> [SharedList] {
        let query = normalizedSearchQuery
        guard !query.isEmpty else { return store.lists }

        return store.lists.filter { list in
            list.name.localizedCaseInsensitiveContains(query)
                || list.type.localizedCaseInsensitiveContains(query)
                || (list.savedPlaceName?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private var normalizedSearchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    /// Renders detail destination with a concrete store instance.
    private func detailDestination(for listId: UUID) -> some View {
        if let store = listStore {
            SharedListDetailView(
                store: store,
                listId: listId,
                actorId: authRepo.currentUser?.id
            )
            .onAppear {
                Log.msg("Resolving shared list destination for listId=\(listId.uuidString). storeReady=true")
            }
        } else {
            ProgressView("lists.detail.loading")
                .onAppear {
                    Log.msg("Resolving shared list destination for listId=\(listId.uuidString). storeReady=false")
                }
                .task {
                    Log.msg("Shared list destination missing store. Recreating store for listId=\(listId.uuidString)")
                    await setupStoreIfNeeded(performRemoteRefresh: false)
                }
        }
    }

    @MainActor
    /// Sets up store if needed.
    private func setupStoreIfNeeded(performRemoteRefresh: Bool = true) async {
        guard listStore == nil else { return }
        Log.msg("Creating SharedListStore. performRemoteRefresh=\(performRemoteRefresh) selectedSpace=\(spaceRepo.selectedSpace?.id.uuidString ?? "nil")")
        let repo = SharedListRepository(client: SupabaseConfig.client, context: modelContext)
        let store = SharedListStore(modelContext: modelContext, repository: repo)
        listStore = store
        store.setSpace(spaceRepo.selectedSpace?.id)

        if performRemoteRefresh && !isPreview {
            await store.refreshRemote()
        }
    }

    @MainActor
    private func refreshLists() async {
        await listStore?.syncPending()
        await listStore?.refreshRemote()
    }

    private func availablePlaces() -> [SavedPlace] {
        guard let spaceId = spaceRepo.selectedSpace?.id else { return [] }
        do {
            return try modelContext.fetch(
                FetchDescriptor<SavedPlace>(
                    predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                    sortBy: [SortDescriptor(\.name, order: .forward)]
                )
            )
        } catch {
            return []
        }
    }
}

struct AddSharedListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo

    let store: SharedListStore
    let actorId: UUID?
    let availablePlaces: [SavedPlace]
    let onCreated: (UUID) -> Void
    var initialSavedPlaceId: UUID? = nil
    var originLabel: String? = nil

    @State private var name = ""
    @State private var selectedType: SharedListType = .shopping
    @State private var selectedIconName = "checklist"
    @State private var selectedIconColorHex = "#6366F1"
    @State private var savedPlaceId: UUID?
    @State private var isSaving = false
    @State private var showStylePicker = false
    @State private var isPresentingAddPlace = false
    @FocusState private var isNameFocused: Bool

    init(
        store: SharedListStore,
        actorId: UUID?,
        availablePlaces: [SavedPlace],
        onCreated: @escaping (UUID) -> Void,
        initialSavedPlaceId: UUID? = nil,
        originLabel: String? = nil
    ) {
        self.store = store
        self.actorId = actorId
        self.availablePlaces = availablePlaces
        self.onCreated = onCreated
        self.initialSavedPlaceId = initialSavedPlaceId
        self.originLabel = originLabel
        _savedPlaceId = State(initialValue: initialSavedPlaceId)
    }

    var body: some View {
        AdaptiveFormContent {
            Form {
                if let originLabel {
                    Section {
                        OpenedFromBadge(title: originLabel)
                    }
                }
                TextField("lists.editor.field.name", text: $name)
                    .prominentFormTextInput()
                    .focused($isNameFocused)
                SelectionMenuRow(title: "Typ", value: selectedType.rawValue.capitalized) {
                    ForEach(SharedListType.allCases) { type in
                        Button(type.rawValue.capitalized) { selectedType = type }
                    }
                }
                SelectionMenuRow(title: "Miejsce", value: selectedPlaceTitle, isPlaceholder: savedPlaceId == nil) {
                    Button("Brak miejsca") { savedPlaceId = nil }
                    ForEach(resolvedAvailablePlaces) { place in
                        Button(place.name) { savedPlaceId = place.id }
                    }
                    Divider()
                    Button("Dodaj nowe miejsce") { isPresentingAddPlace = true }
                }
                DisclosureGroup("Styl", isExpanded: $showStylePicker) {
                    OperationStylePicker(iconName: $selectedIconName, colorHex: $selectedIconColorHex)
                }
            }
            .navigationTitle("lists.editor.title.new")
            .modalInlineTitleDisplayMode()
            .toolbar {
                ModalCloseToolbarItem {
                    dismiss()
                }
                ModalConfirmToolbarItem(
                    isDisabled: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving,
                    isProcessing: isSaving,
                    action: {
                        Task {
                            await saveList()
                        }
                    }
                )
            }
            .sheet(isPresented: $isPresentingAddPlace) {
                QuickAddPlaceSheet(originLabel: originLabel) { place in
                    savedPlaceId = place.id
                }
            }
            .onAppear {
                if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    isNameFocused = true
                }
            }
        }
    }

    @MainActor
    /// Saves a new list and opens its detail view.
    private func saveList() async {
        isSaving = true
        defer { isSaving = false }

        let listId = await store.addList(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            type: selectedType,
            iconName: selectedIconName,
            iconColorHex: selectedIconColorHex,
            savedPlaceId: savedPlaceId,
            savedPlaceName: resolvedAvailablePlaces.first(where: { $0.id == savedPlaceId })?.name,
            actor: actorId
        )
        guard let listId else { return }
        dismiss()
        onCreated(listId)
    }

    private var resolvedAvailablePlaces: [SavedPlace] {
        guard let spaceId = spaceRepo.selectedSpace?.id else { return availablePlaces }
        do {
            return try modelContext.fetch(
                FetchDescriptor<SavedPlace>(
                    predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                    sortBy: [SortDescriptor(\.name, order: .forward)]
                )
            )
        } catch {
            return availablePlaces
        }
    }

    private var selectedPlaceTitle: String {
        resolvedAvailablePlaces.first(where: { $0.id == savedPlaceId })?.name ?? "Brak miejsca"
    }
}

struct SharedListDetailView: View {
    let store: SharedListStore
    let listId: UUID
    let actorId: UUID?
    var openedFromLabel: String? = nil

    @State private var newItemName = ""

    private var list: SharedList? {
        store.lists.first { $0.id == listId }
    }

    private var items: [SharedListItem] {
        store.itemsByList[listId] ?? []
    }

    var body: some View {
        List {
            if let openedFromLabel {
                Section {
                    OpenedFromBadge(title: openedFromLabel)
                }
            }
            if let error = store.lastErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Section("lists.items.section.newItem") {
                HStack {
                    TextField("lists.items.field.name", text: $newItemName)
                        .prominentFormTextInput()
                    Button {
                        Task {
                            await addItem()
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .disabled(newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 2)
            }

            Section("lists.items.section.items") {
                if let savedPlaceName = list?.savedPlaceName, !savedPlaceName.isEmpty {
                    Label(savedPlaceName, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if items.isEmpty {
                    Text("lists.items.empty")
                        .foregroundStyle(.secondary)
                }
                ForEach(items) { item in
                    HStack {
                        Button {
                            Task {
                                await store.toggleItem(item, actor: actorId)
                            }
                        } label: {
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.isCompleted ? .green : .secondary)
                                .frame(width: 22)
                        }
                        .buttonStyle(.plain)
                        Text(item.title)
                            .strikethrough(item.isCompleted)
                        Spacer()
                        Menu {
                            Button(role: .destructive) {
                                Task {
                                    await store.deleteItem(item, actor: actorId)
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
                    .padding(.vertical, 6)
                    .padding(.horizontal, 2)
                }
                .onDelete { offsets in
                    let values = offsets.map { items[$0] }
                    Task {
                        for item in values {
                            await store.deleteItem(item, actor: actorId)
                        }
                    }
                }
            }
        }
        .navigationTitle(list?.name ?? String(localized: "lists.detail.fallbackTitle"))
        .refreshable {
            await store.syncPending()
            await store.refreshRemote()
        }
        .onAppear {
            let listName = list?.name ?? "nil"
            let knownIds = store.lists.map(\.id.uuidString).joined(separator: ",")
            Log.msg("SharedListDetailView appear. requestedListId=\(listId.uuidString) resolvedName=\(listName) itemCount=\(items.count) knownListIds=[\(knownIds)]")
            if list == nil {
                Log.error("SharedListDetailView could not resolve list for listId=\(listId.uuidString)")
            }
        }
    }

    @MainActor
    /// Adds a new item to the current list.
    private func addItem() async {
        let value = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        await store.addItem(listId: listId, title: value)
        newItemName = ""
    }
}

#Preview("lists.view.title") {
    let schema = Schema([
        UserProfile.self,
        Space.self,
        SpaceMembership.self,
        SpaceInvitation.self,
        Mission.self,
        Incident.self,
        LinkedThing.self,
        Assignment.self,
        SharedList.self,
        SharedListItem.self
    ])
    let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext

    let user = UserProfile(id: UUID(), email: "preview@ufo.app", fullName: "Preview User", role: "admin")
    let space = Space(id: UUID(), name: "Family Crew", inviteCode: "UFO123")
    context.insert(user)
    context.insert(space)
    context.insert(SpaceMembership(user: user, space: space, role: "admin"))

    let shopping = SharedList(spaceId: space.id, name: "Weekend shopping", type: SharedListType.shopping.rawValue)
    context.insert(shopping)
    context.insert(SharedListItem(listId: shopping.id, title: "Milk", isCompleted: true, position: 1))
    context.insert(SharedListItem(listId: shopping.id, title: "Bread", isCompleted: false, position: 2))

    do {
        try context.save()
    } catch {
        Log.dbError("SharedLists preview context.save", error)
    }

    let authRepo = AuthRepository(client: SupabaseConfig.client, isLoggedIn: true, currentUser: user)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    spaceRepo.selectedSpace = space

    return SharedListsView()
        .environment(authRepo)
        .environment(spaceRepo)
        .modelContainer(container)
}
