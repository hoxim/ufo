#if os(macOS)

import SwiftUI
import SwiftData

struct MacListsScreen: View {
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
            if let listStore {
                content(store: listStore)
            } else {
                ProgressView("lists.view.loading")
            }
        }
        .appScreenBackground()
        .navigationTitle("lists.view.title")
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
        .navigationDestination(isPresented: $isAddingList) {
            if let listStore {
                MacAddListView(
                    store: listStore,
                    actorId: authRepo.currentUser?.id,
                    availablePlaces: availablePlaces()
                ) { createdListId in
                    selectedListId = createdListId
                }
                .frame(minWidth: 560, minHeight: 520)
            }
        }
        .task {
            Log.msg("MacListsScreen.task start. autoPresentAdd=\(autoPresentAdd) selectedSpace=\(spaceRepo.selectedSpace?.id.uuidString ?? "nil")")
            await setupStoreIfNeeded(performRemoteRefresh: !autoPresentAdd)
            if autoPresentAdd && !didAutoPresentAdd && listStore != nil {
                didAutoPresentAdd = true
                try? await Task.sleep(for: .milliseconds(150))
                isAddingList = true
            }
        }
        .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
            Log.msg("MacListsScreen selected space changed to \(newValue?.uuidString ?? "nil")")
            listStore?.setSpace(newValue)
            selectedListId = nil
            Task { await listStore?.refreshRemote() }
        }
        .safeAreaInset(edge: .bottom) {
            FeatureBottomSearchBar(text: $searchText, prompt: "lists.search.prompt")
        }
    }

    @ViewBuilder
    private func content(store: SharedListStore) -> some View {
        let lists = filteredLists(in: store)

        if lists.isEmpty {
            ContentUnavailableView(
                "lists.view.empty",
                systemImage: "list.bullet.clipboard",
                description: Text("lists.view.emptyHint")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(selection: $selectedListId) {
                if let error = store.lastErrorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                ForEach(lists) { list in
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
                    .padding(.vertical, 6)
                    .tag(list.id)
                    .contextMenu {
                        Button(role: .destructive) {
                            Task {
                                await store.deleteList(list, actor: authRepo.currentUser?.id)
                            }
                        } label: {
                            Label("common.delete", systemImage: "trash")
                        }
                    }
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
    private func detailDestination(for listId: UUID) -> some View {
        if let store = listStore {
            MacListDetailView(
                store: store,
                listId: listId,
                actorId: authRepo.currentUser?.id
            )
        } else {
            ProgressView("lists.detail.loading")
                .task {
                    await setupStoreIfNeeded(performRemoteRefresh: false)
                }
        }
    }

    @MainActor
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

#endif
