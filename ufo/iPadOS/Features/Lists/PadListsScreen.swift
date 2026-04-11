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
        .navigationSplitViewStyle(.balanced)
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

            VStack(spacing: 0) {
                PadListsColumnHeader(
                    selectedSpaceName: spaceRepo.selectedSpace?.name,
                    listCount: lists.count
                )

                if let error = listStore.lastErrorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }

                if lists.isEmpty {
                    ContentUnavailableView(
                        "lists.view.empty",
                        systemImage: "list.bullet.clipboard",
                        description: Text("lists.view.emptyHint")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 20)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(lists.enumerated()), id: \.element.id) { index, list in
                                Button {
                                    selectedListId = list.id
                                } label: {
                                    PadListsColumnRow(
                                        list: list,
                                        itemCount: listStore.itemsByList[list.id]?.count ?? 0,
                                        isSelected: selectedListId == list.id
                                    )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Task {
                                            await listStore.deleteList(list, actor: authRepo.currentUser?.id)
                                            if selectedListId == list.id {
                                                selectedListId = listStore.lists.first?.id
                                            }
                                        }
                                    } label: {
                                        Label("common.delete", systemImage: "trash")
                                    }
                                }

                                if index < lists.count - 1 {
                                    Divider()
                                        .padding(.leading, 72)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                }
            }
            .background(Color.systemBackground)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(AppTheme.Colors.divider)
                    .frame(width: 1)
                    .ignoresSafeArea()
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 380)
            .searchable(text: $searchText, prompt: "lists.search.prompt")
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

struct PadListsSidebarWorkspace<Sidebar: View>: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo

    private let sidebar: Sidebar

    @State private var listStore: SharedListStore?
    @State private var isAddingList = false
    @State private var selectedListId: UUID?
    @State private var searchText = ""
    @State private var completionFilter: PadListCompletionFilter = .all

    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    init(@ViewBuilder sidebar: () -> Sidebar) {
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
            await setupStoreIfNeeded()
        }
        .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
            listStore?.setSpace(newValue)
            selectedListId = nil
            Task {
                await listStore?.refreshRemote()
                if selectedListId == nil {
                    selectedListId = listStore?.lists.first?.id
                }
            }
        }
    }

    @ViewBuilder
    private var contentColumn: some View {
        if let listStore {
            let lists = filteredLists(in: listStore)
            VStack(spacing: 0) {
                if let error = listStore.lastErrorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }

                if lists.isEmpty {
                    ContentUnavailableView(
                        "lists.view.empty",
                        systemImage: "list.bullet.clipboard",
                        description: Text("lists.view.emptyHint")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 20)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(lists.enumerated()), id: \.element.id) { index, list in
                                Button {
                                    selectedListId = list.id
                                } label: {
                                    PadListsColumnRow(
                                        list: list,
                                        itemCount: listStore.itemsByList[list.id]?.count ?? 0,
                                        isSelected: selectedListId == list.id
                                    )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Task {
                                            await listStore.deleteList(list, actor: authRepo.currentUser?.id)
                                            if selectedListId == list.id {
                                                selectedListId = listStore.lists.first?.id
                                            }
                                        }
                                    } label: {
                                        Label("common.delete", systemImage: "trash")
                                    }
                                }

                                if index < lists.count - 1 {
                                    Divider()
                                        .padding(.leading, 72)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                }
            }
            .background(Color.systemBackground)
            .searchable(text: $searchText, prompt: "lists.search.prompt")
            .refreshable {
                await refreshLists()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padWorkspaceTopBarTitle("lists.view.title")
            .toolbar {
                ToolbarItemGroup(placement: .platformTopBarTrailing) {
                    Menu {
                        ForEach(PadListCompletionFilter.allCases) { filter in
                            Button {
                                completionFilter = filter
                            } label: {
                                if completionFilter == filter {
                                    Label(filter.title, systemImage: "checkmark")
                                } else {
                                    Text(filter.title)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: completionFilter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                    .accessibilityLabel("Filtruj listy")

                    Button {
                        isAddingList = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "lists.view.action.add"))
                    .disabled(spaceRepo.selectedSpace == nil)
                }
            }
        } else {
            ProgressView("lists.view.loading")
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ProgressView("lists.detail.loading")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func filteredLists(in store: SharedListStore) -> [SharedList] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.lists.filter { list in
            let matchesQuery = query.isEmpty
                || list.name.localizedCaseInsensitiveContains(query)
                || list.type.localizedCaseInsensitiveContains(query)
                || (list.savedPlaceName?.localizedCaseInsensitiveContains(query) ?? false)

            return matchesQuery && matchesCompletionFilter(for: list, in: store)
        }
    }

    private func matchesCompletionFilter(for list: SharedList, in store: SharedListStore) -> Bool {
        let items = store.itemsByList[list.id] ?? []

        switch completionFilter {
        case .all:
            return true
        case .open:
            return items.isEmpty || items.contains(where: { !$0.isCompleted })
        case .completed:
            return !items.isEmpty && items.allSatisfy(\.isCompleted)
        }
    }

    @MainActor
    private func setupStoreIfNeeded() async {
        guard listStore == nil else { return }

        let repo = SharedListRepository(client: SupabaseConfig.client, context: modelContext)
        let store = SharedListStore(modelContext: modelContext, repository: repo)
        listStore = store
        store.setSpace(spaceRepo.selectedSpace?.id)

        if !isPreview {
            await store.refreshRemote()
        }

        if selectedListId == nil {
            selectedListId = store.lists.first?.id
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

private enum PadListCompletionFilter: String, CaseIterable, Identifiable {
    case all
    case open
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "Wszystkie"
        case .open:
            return "Otwarte"
        case .completed:
            return "Ukonczone"
        }
    }
}

private struct PadListsColumnHeader: View {
    let selectedSpaceName: String?
    let listCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("lists.view.title")
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                if let selectedSpaceName, !selectedSpaceName.isEmpty {
                    Text(selectedSpaceName)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(verbatim: "\(listCount)")
                    .foregroundStyle(.secondary)
            }
            .font(.footnote)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }
}

private struct PadListsColumnRow: View {
    let list: SharedList
    let itemCount: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: list.iconName ?? "checklist")
                .foregroundStyle(Color(hex: list.iconColorHex ?? "#6366F1"))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(list.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(list.type.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let savedPlaceName = list.savedPlaceName, !savedPlaceName.isEmpty {
                    Text(savedPlaceName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(verbatim: "\(itemCount)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(selectionBackground)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.Colors.listSelection)
        } else {
            Color.clear
        }
    }
}

#endif
