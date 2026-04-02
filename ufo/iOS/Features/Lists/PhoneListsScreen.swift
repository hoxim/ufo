#if os(iOS)

import SwiftUI
import SwiftData

struct PhoneListsScreen: View {
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
        .sheet(isPresented: $isAddingList) {
            if let listStore {
                PhoneAddListView(
                    store: listStore,
                    actorId: authRepo.currentUser?.id,
                    availablePlaces: availablePlaces()
                ) { createdListId in
                    selectedListId = createdListId
                }
                .presentationDetents([.medium, .large])
            }
        }
        .task {
            Log.msg("PhoneListsScreen.task start. autoPresentAdd=\(autoPresentAdd) selectedSpace=\(spaceRepo.selectedSpace?.id.uuidString ?? "nil")")
            await setupStoreIfNeeded(performRemoteRefresh: !autoPresentAdd)
            if autoPresentAdd && !didAutoPresentAdd && listStore != nil {
                didAutoPresentAdd = true
                try? await Task.sleep(for: .milliseconds(300))
                isAddingList = true
            }
        }
        .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
            Log.msg("PhoneListsScreen selected space changed to \(newValue?.uuidString ?? "nil")")
            listStore?.setSpace(newValue)
            selectedListId = nil
            Task { await listStore?.refreshRemote() }
        }
        .safeAreaInset(edge: .bottom) {
            FeatureBottomSearchBar(text: $searchText, prompt: "Search lists")
        }
    }

    @ViewBuilder
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
            PhoneListDetailView(
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

#Preview("Phone Lists") {
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

    try? context.save()

    let authRepo = AuthRepository(client: SupabaseConfig.client, isLoggedIn: true, currentUser: user)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    spaceRepo.selectedSpace = space

    return NavigationStack {
        PhoneListsScreen()
    }
    .environment(authRepo)
    .environment(spaceRepo)
    .modelContainer(container)
}

#endif
