#if os(iOS)

import SwiftUI
import SwiftData

struct PadListsScreen: View {
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
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .appScreenBackground()
        .navigationTitle("lists.view.title")
        .hideTabBarIfSupported()
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
        .sheet(isPresented: $isAddingList) {
            if let listStore {
                PadAddListView(
                    store: listStore,
                    actorId: authRepo.currentUser?.id,
                    availablePlaces: availablePlaces()
                ) { createdListId in
                    selectedListId = createdListId
                }
                .presentationDetents([.medium, .large])
                .frame(minWidth: 560, minHeight: 520)
            }
        }
        .task {
            Log.msg("PadListsScreen.task start. autoPresentAdd=\(autoPresentAdd) selectedSpace=\(spaceRepo.selectedSpace?.id.uuidString ?? "nil")")
            await setupStoreIfNeeded(performRemoteRefresh: !autoPresentAdd)
            if autoPresentAdd && !didAutoPresentAdd && listStore != nil {
                didAutoPresentAdd = true
                try? await Task.sleep(for: .milliseconds(250))
                isAddingList = true
            }
        }
        .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
            Log.msg("PadListsScreen selected space changed to \(newValue?.uuidString ?? "nil")")
            listStore?.setSpace(newValue)
            selectedListId = nil
            Task { await listStore?.refreshRemote() }
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        if let listStore {
            let lists = filteredLists(in: listStore)

            List(selection: $selectedListId) {
                if let error = listStore.lastErrorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if lists.isEmpty {
                    ContentUnavailableView(
                        "lists.view.empty",
                        systemImage: "list.bullet.clipboard",
                        description: Text("lists.view.emptyHint")
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                    .listRowBackground(Color.clear)
                } else {
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
                            Text("\(listStore.itemsByList[list.id]?.count ?? 0)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                        .tag(list.id)
                    }
                }
            }
            .appPrimaryListChrome()
            .searchable(text: $searchText, prompt: "Search lists")
            .refreshable {
                await refreshLists()
            }
        } else {
            ProgressView("lists.view.loading")
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let store = listStore, let selectedListId {
            PadListDetailView(
                store: store,
                listId: selectedListId,
                actorId: authRepo.currentUser?.id
            )
        } else if listStore != nil {
            ContentUnavailableView(
                "Wybierz listę",
                systemImage: "sidebar.left",
                description: Text("Wybierz listę z lewej kolumny, aby zobaczyć szczegóły i pozycje.")
            )
        } else {
            ProgressView("lists.detail.loading")
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

    @MainActor
    private func setupStoreIfNeeded(performRemoteRefresh: Bool = true) async {
        guard listStore == nil else { return }

        let repo = SharedListRepository(client: SupabaseConfig.client, context: modelContext)
        let store = SharedListStore(modelContext: modelContext, repository: repo)
        listStore = store
        store.setSpace(spaceRepo.selectedSpace?.id)

        if selectedListId == nil {
            selectedListId = store.lists.first?.id
        }

        if performRemoteRefresh && !isPreview {
            await store.refreshRemote()
            if selectedListId == nil {
                selectedListId = store.lists.first?.id
            }
        }
    }

    @MainActor
    private func refreshLists() async {
        await listStore?.syncPending()
        await listStore?.refreshRemote()
        if selectedListId == nil {
            selectedListId = listStore?.lists.first?.id
        }
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
