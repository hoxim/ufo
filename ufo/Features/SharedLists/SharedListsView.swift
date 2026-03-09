import SwiftUI
import SwiftData

struct SharedListsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo

    @State private var listStore: SharedListStore?
    @State private var isAddingList = false
    @State private var navPath: [UUID] = []
    @State private var didAutoPresentAdd = false

    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    let autoPresentAdd: Bool

    init(autoPresentAdd: Bool = false) {
        self.autoPresentAdd = autoPresentAdd
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            Group {
                if let store = listStore {
                    content(store: store)
                } else {
                    ProgressView("lists.view.loading")
                }
            }
            .navigationTitle("lists.view.title")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingList = true
                    } label: {
                        Label("lists.view.action.add", systemImage: "plus")
                    }
                    .disabled(spaceRepo.selectedSpace == nil || listStore == nil)
                }
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await listStore?.syncPending() }
                    } label: {
                        Label("common.sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(listStore?.isSyncing == true || spaceRepo.selectedSpace == nil)
                }
            }
            .sheet(isPresented: $isAddingList) {
                if let listStore {
                    AddSharedListView(
                        store: listStore,
                        actorId: authRepo.currentUser?.id
                    ) { createdListId in
                        navPath.append(createdListId)
                    }
                    #if os(iOS)
                    .presentationDetents([.medium, .large])
                    #endif
                    #if os(macOS)
                    .frame(minWidth: 560, minHeight: 520)
                    #endif
                }
            }
            .navigationDestination(for: UUID.self) { listId in
                if let listStore {
                    SharedListDetailView(
                        store: listStore,
                        listId: listId,
                        actorId: authRepo.currentUser?.id
                    )
                } else {
                    ProgressView("lists.detail.loading")
                }
            }
            .task {
                await setupStoreIfNeeded(performRemoteRefresh: !autoPresentAdd)
                if autoPresentAdd && !didAutoPresentAdd && listStore != nil {
                    didAutoPresentAdd = true
                    try? await Task.sleep(for: .milliseconds(300))
                    isAddingList = true
                }
            }
            .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
                listStore?.setSpace(newValue)
                navPath = []
                Task { await listStore?.refreshRemote() }
            }
        }
    }

    @ViewBuilder
    /// Renders main list content.
    private func content(store: SharedListStore) -> some View {
        if store.lists.isEmpty {
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

                ForEach(store.lists) { list in
                    NavigationLink(value: list.id) {
                        HStack(spacing: 12) {
                            Image(systemName: list.iconName ?? "checklist")
                                .foregroundStyle(Color(hex: list.iconColorHex ?? "#6366F1"))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(list.name)
                                    .font(.headline)
                                Text(list.type.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            let count = store.itemsByList[list.id]?.count ?? 0
                            Text("\(count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    @MainActor
    /// Sets up store if needed.
    private func setupStoreIfNeeded(performRemoteRefresh: Bool = true) async {
        guard listStore == nil else { return }
        let repo = SharedListRepository(client: SupabaseConfig.client, context: modelContext)
        let store = SharedListStore(modelContext: modelContext, repository: repo)
        listStore = store
        store.setSpace(spaceRepo.selectedSpace?.id)

        if performRemoteRefresh && !isPreview {
            await store.refreshRemote()
        }
    }
}

private struct AddSharedListView: View {
    @Environment(\.dismiss) private var dismiss

    let store: SharedListStore
    let actorId: UUID?
    let onCreated: (UUID) -> Void

    @State private var name = ""
    @State private var selectedType: SharedListType = .shopping
    @State private var selectedIconName = "checklist"
    @State private var selectedIconColorHex = "#6366F1"
    @State private var isSaving = false
    @State private var showStylePicker = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("lists.editor.field.name", text: $name)
                Picker("lists.editor.field.type", selection: $selectedType) {
                    ForEach(SharedListType.allCases) { type in
                        Text(type.rawValue.capitalized).tag(type)
                    }
                }
                DisclosureGroup("Style", isExpanded: $showStylePicker) {
                    OperationStylePicker(iconName: $selectedIconName, colorHex: $selectedIconColorHex)
                }
            }
            .navigationTitle("lists.editor.title.new")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await saveList()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
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
            actor: actorId
        )
        guard let listId else { return }
        dismiss()
        onCreated(listId)
    }
}

private struct SharedListDetailView: View {
    let store: SharedListStore
    let listId: UUID
    let actorId: UUID?

    @State private var newItemName = ""

    private var list: SharedList? {
        store.lists.first { $0.id == listId }
    }

    private var items: [SharedListItem] {
        store.itemsByList[listId] ?? []
    }

    var body: some View {
        List {
            if let error = store.lastErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Section("lists.items.section.newItem") {
                HStack {
                    TextField("lists.items.field.name", text: $newItemName)
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
            }

            Section("lists.items.section.items") {
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
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task {
                        await store.syncPending()
                    }
                } label: {
                    Label("common.sync", systemImage: "arrow.triangle.2.circlepath")
                }
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
