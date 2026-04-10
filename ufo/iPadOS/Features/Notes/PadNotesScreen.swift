#if os(iOS)

import SwiftUI
import SwiftData

struct PadNotesScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo

    @State private var noteStore: NoteStore?
    @State private var editorTarget: PadNoteEditorTarget?
    @State private var missions: [Mission] = []
    @State private var incidents: [Incident] = []
    @State private var people: [UserProfile] = []
    @State private var recentLocations: [LocationPing] = []
    @State private var selectedNoteId: UUID?
    @State private var selectedFolderId: UUID?
    @State private var newFolderName = ""
    @State private var showFolderCreator = false
    @State private var searchText = ""
    @State private var didAutoPresentAdd = false

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
        .navigationTitle("notes.view.title")
        .hideTabBarIfSupported()
        .toolbar {
            ToolbarItem(placement: .platformTopBarLeading) {
                Button {
                    showFolderCreator = true
                } label: {
                    Label("notes.view.action.addFolder", systemImage: "folder.badge.plus")
                }
                .disabled(noteStore == nil || spaceRepo.selectedSpace == nil)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    editorTarget = PadNoteEditorTarget()
                } label: {
                    Label("notes.view.action.addNote", systemImage: "plus")
                }
                .disabled(noteStore == nil || spaceRepo.selectedSpace == nil)
            }
        }
        .sheet(item: $editorTarget) { target in
            if let noteStore {
                NavigationStack {
                    PadNoteEditorView(
                        noteStore: noteStore,
                        note: target.note,
                        folders: noteStore.folders,
                        missions: missions,
                        incidents: incidents,
                        people: people,
                        locations: recentLocations,
                        savedPlaces: savedPlaces(),
                        actorId: authRepo.currentUser?.id,
                        onSaved: { createdOrUpdatedId in
                            selectedNoteId = createdOrUpdatedId
                        }
                    )
                }
                .presentationDetents([.medium, .large])
                .frame(minWidth: 640, minHeight: 620)
            }
        }
        .sheet(isPresented: $showFolderCreator) {
            AdaptiveFormContent {
                Form {
                    TextField("notes.folder.field.name", text: $newFolderName)
                }
                .navigationTitle("notes.folder.title.new")
                .modalInlineTitleDisplayMode()
                .toolbar {
                    ModalCloseToolbarItem {
                        showFolderCreator = false
                    }
                    ModalConfirmToolbarItem(
                        isDisabled: newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        isProcessing: false,
                        action: {
                            Task {
                                let value = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !value.isEmpty else { return }
                                await noteStore?.addFolder(name: value, actor: authRepo.currentUser?.id)
                                newFolderName = ""
                                showFolderCreator = false
                            }
                        }
                    )
                }
            }
            .presentationDetents([.medium, .large])
            .frame(minWidth: 520, minHeight: 380)
        }
        .task {
            await setupStoreIfNeeded(performRemoteRefresh: !autoPresentAdd)
            loadReferences()
            if autoPresentAdd && !didAutoPresentAdd && noteStore != nil {
                didAutoPresentAdd = true
                try? await Task.sleep(for: .milliseconds(250))
                editorTarget = PadNoteEditorTarget()
            }
        }
        .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
            guard let noteStore else { return }
            noteStore.setSpace(newValue)
            selectedNoteId = nil
            loadReferences()
            Task {
                await noteStore.refreshRemote()
                if selectedNoteId == nil {
                    selectedNoteId = filteredNotes.first?.id
                }
            }
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        if let noteStore {
            VStack(spacing: 0) {
                PadWorkspaceColumnHeader(
                    title: "notes.view.title",
                    selectedSpaceName: spaceRepo.selectedSpace?.name,
                    itemCount: filteredNotes.count
                ) {
                    notesFilterIndicator
                }

                folderPickerBar

                List(selection: $selectedNoteId) {
                    if let error = noteStore.lastErrorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if !pinnedNotes.isEmpty {
                        Section("Pinned") {
                            ForEach(pinnedNotes) { note in
                                sidebarRow(for: note)
                            }
                        }
                    }

                    ForEach(datedSections) { section in
                        Section(section.title) {
                            ForEach(section.notes) { note in
                                sidebarRow(for: note)
                            }
                        }
                    }

                    if filteredNotes.isEmpty {
                        ContentUnavailableView(
                            "notes.view.empty",
                            systemImage: "note.text",
                            description: Text("Dodaj pierwszą notatkę albo zmień filtry, aby zobaczyć wyniki.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 220)
                        .listRowBackground(Color.clear)
                    }
                }
                .appPrimaryListChrome()
                .tint(AppTheme.Colors.listSelection)
                .searchable(text: $searchText, prompt: "Szukaj notatek")
                .refreshable {
                    await refreshNotes()
                }
            }
        } else {
            ProgressView("notes.view.loading")
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let note = selectedNote {
            PadNoteDetailView(
                note: note,
                presentationMode: .embedded,
                onEdit: {
                    editorTarget = PadNoteEditorTarget(note: note)
                }
            )
        } else if noteStore != nil {
            ContentUnavailableView(
                "Wybierz notatkę",
                systemImage: "sidebar.left",
                description: Text("Wybierz notatkę z lewej kolumny, aby zobaczyć szczegóły.")
            )
        } else {
            ProgressView("notes.detail.loading")
        }
    }

    private var folderPickerBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    selectedFolderId = nil
                    if selectedNoteId == nil {
                        selectedNoteId = filteredNotes.first?.id
                    }
                } label: {
                    Text("notes.filter.all")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selectedFolderId == nil ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                ForEach(noteStore?.folders ?? []) { folder in
                    Button {
                        selectedFolderId = folder.id
                        if !filteredNotes.contains(where: { $0.id == selectedNoteId }) {
                            selectedNoteId = filteredNotes.first?.id
                        }
                    } label: {
                        Text(folder.name)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedFolderId == folder.id ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top, 4)
        }
        .padding(.bottom, 8)
        .background(Color.systemBackground)
        .overlay(alignment: .bottom) {
            Divider()
                .opacity(0.35)
        }
    }

    private var notesFilterIndicator: some View {
        Image(systemName: selectedFolderId == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
            .font(.title3)
            .foregroundStyle(selectedFolderId == nil ? Color.secondary : Color.accentColor)
            .accessibilityLabel("Filtr folderów")
    }

    private func sidebarRow(for note: Note) -> some View {
        PadNoteSidebarRow(note: note)
            .tag(note.id)
            .contextMenu {
                Button {
                    editorTarget = PadNoteEditorTarget(note: note)
                } label: {
                    Label("common.edit", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    Task {
                        await noteStore?.deleteNote(note, actor: authRepo.currentUser?.id)
                        if selectedNoteId == note.id {
                            selectedNoteId = filteredNotes.first?.id
                        }
                    }
                } label: {
                    Label("common.delete", systemImage: "trash")
                }
            }
    }

    private var selectedNote: Note? {
        guard let selectedNoteId else { return nil }
        return noteStore?.notes.first(where: { $0.id == selectedNoteId })
    }

    private var filteredNotes: [Note] {
        let notes = noteStore?.notes.sorted {
            if $0.isPinnedValue != $1.isPinnedValue {
                return $0.isPinnedValue && !$1.isPinnedValue
            }
            return $0.updatedAt > $1.updatedAt
        } ?? []

        return notes.filter { note in
            let matchesFolder = selectedFolderId == nil || note.folderId == selectedFolderId
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty || noteMatchesSearch(note, query: query)
            return matchesFolder && matchesSearch
        }
    }

    private var pinnedNotes: [Note] {
        filteredNotes.filter(\.isPinnedValue)
    }

    private var datedSections: [PadNoteDaySection] {
        let notes = filteredNotes.filter { !$0.isPinnedValue }
        let grouped = Dictionary(grouping: notes) { Calendar.current.startOfDay(for: $0.updatedAt) }

        return grouped
            .map { date, notes in
                PadNoteDaySection(
                    date: date,
                    notes: notes.sorted { $0.updatedAt > $1.updatedAt }
                )
            }
            .sorted { $0.date > $1.date }
    }

    private func noteMatchesSearch(_ note: Note, query: String) -> Bool {
        let normalizedQuery = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let haystacks = [
            note.title,
            note.previewText,
            note.savedPlaceName ?? "",
            note.relatedLocationLabel ?? "",
            note.attachedLinkURL ?? "",
            note.resolvedTags.joined(separator: " ")
        ]

        return haystacks.contains {
            $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .contains(normalizedQuery)
        }
    }

    @MainActor
    private func setupStoreIfNeeded(performRemoteRefresh: Bool = true) async {
        guard noteStore == nil else { return }
        let repository = NoteRepository(client: SupabaseConfig.client, context: modelContext)
        let store = NoteStore(modelContext: modelContext, repository: repository)
        noteStore = store
        store.setSpace(spaceRepo.selectedSpace?.id)

        if selectedNoteId == nil {
            selectedNoteId = filteredNotes.first?.id ?? store.notes.first?.id
        }

        if performRemoteRefresh && !isPreview {
            await store.refreshRemote()
            if selectedNoteId == nil {
                selectedNoteId = filteredNotes.first?.id ?? store.notes.first?.id
            }
        }
    }

    @MainActor
    private func refreshNotes() async {
        await noteStore?.syncPending()
        await noteStore?.refreshRemote()
        loadReferences()
        if selectedNoteId == nil {
            selectedNoteId = filteredNotes.first?.id
        }
    }

    private func loadReferences() {
        guard let spaceId = spaceRepo.selectedSpace?.id else {
            missions = []
            incidents = []
            people = []
            recentLocations = []
            return
        }
        do {
            missions = try modelContext.fetch(
                FetchDescriptor<Mission>(
                    predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                    sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
                )
            )
            incidents = try modelContext.fetch(
                FetchDescriptor<Incident>(
                    predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                    sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
                )
            )
            recentLocations = try modelContext.fetch(
                FetchDescriptor<LocationPing>(
                    predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                    sortBy: [SortDescriptor(\.recordedAt, order: .reverse)]
                )
            )
            people = authRepo.currentUser?
                .memberships
                .filter { $0.spaceId == spaceId }
                .compactMap(\.user) ?? []
        } catch {
            Log.dbError("PadNotesScreen.loadReferences (SwiftData fetch)", error)
            missions = []
            incidents = []
            people = []
            recentLocations = []
        }
    }

    private func savedPlaces() -> [SavedPlace] {
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

struct PadNotesSidebarWorkspace<Sidebar: View>: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo

    private let sidebar: Sidebar

    @State private var noteStore: NoteStore?
    @State private var editorTarget: PadNoteEditorTarget?
    @State private var missions: [Mission] = []
    @State private var incidents: [Incident] = []
    @State private var people: [UserProfile] = []
    @State private var recentLocations: [LocationPing] = []
    @State private var selectedNoteId: UUID?
    @State private var selectedFolderId: UUID?
    @State private var newFolderName = ""
    @State private var showFolderCreator = false
    @State private var searchText = ""
    @State private var didAutoPresentAdd = false

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
        .sheet(item: $editorTarget) { target in
            if let noteStore {
                NavigationStack {
                    PadNoteEditorView(
                        noteStore: noteStore,
                        note: target.note,
                        folders: noteStore.folders,
                        missions: missions,
                        incidents: incidents,
                        people: people,
                        locations: recentLocations,
                        savedPlaces: savedPlaces(),
                        actorId: authRepo.currentUser?.id,
                        onSaved: { createdOrUpdatedId in
                            selectedNoteId = createdOrUpdatedId
                        }
                    )
                }
                .presentationDetents([.medium, .large])
                .frame(minWidth: 640, minHeight: 620)
            }
        }
        .sheet(isPresented: $showFolderCreator) {
            AdaptiveFormContent {
                Form {
                    TextField("notes.folder.field.name", text: $newFolderName)
                }
                .navigationTitle("notes.folder.title.new")
                .modalInlineTitleDisplayMode()
                .toolbar {
                    ModalCloseToolbarItem {
                        showFolderCreator = false
                    }
                    ModalConfirmToolbarItem(
                        isDisabled: newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        isProcessing: false,
                        action: {
                            Task {
                                let value = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !value.isEmpty else { return }
                                await noteStore?.addFolder(name: value, actor: authRepo.currentUser?.id)
                                newFolderName = ""
                                showFolderCreator = false
                            }
                        }
                    )
                }
            }
            .presentationDetents([.medium, .large])
            .frame(minWidth: 520, minHeight: 380)
        }
        .task {
            await setupStoreIfNeeded(performRemoteRefresh: !autoPresentAdd)
            loadReferences()
            if autoPresentAdd && !didAutoPresentAdd && noteStore != nil {
                didAutoPresentAdd = true
                try? await Task.sleep(for: .milliseconds(250))
                editorTarget = PadNoteEditorTarget()
            }
        }
        .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
            guard let noteStore else { return }
            noteStore.setSpace(newValue)
            selectedNoteId = nil
            loadReferences()
            Task {
                await noteStore.refreshRemote()
                if selectedNoteId == nil {
                    selectedNoteId = filteredNotes.first?.id
                }
            }
        }
    }

    @ViewBuilder
    private var contentColumn: some View {
        if let noteStore {
            VStack(spacing: 0) {
                folderPickerBar

                List(selection: $selectedNoteId) {
                    if let error = noteStore.lastErrorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if !pinnedNotes.isEmpty {
                        Section("Pinned") {
                            ForEach(pinnedNotes) { note in
                                sidebarRow(for: note)
                            }
                        }
                    }

                    ForEach(datedSections) { section in
                        Section(section.title) {
                            ForEach(section.notes) { note in
                                sidebarRow(for: note)
                            }
                        }
                    }

                    if filteredNotes.isEmpty {
                        ContentUnavailableView(
                            "notes.view.empty",
                            systemImage: "note.text",
                            description: Text("Dodaj pierwszą notatkę albo zmień filtry, aby zobaczyć wyniki.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 220)
                        .listRowBackground(Color.clear)
                    }
                }
                .appPrimaryListChrome()
                .tint(AppTheme.Colors.listSelection)
                .searchable(text: $searchText, prompt: "Szukaj notatek")
                .refreshable {
                    await refreshNotes()
                }
            }
            .padWorkspaceTopBarTitle("notes.view.title")
            .toolbar {
                ToolbarItemGroup(placement: .platformTopBarTrailing) {
                    notesFilterIndicator

                    Button {
                        showFolderCreator = true
                    } label: {
                        Label("notes.view.action.addFolder", systemImage: "folder.badge.plus")
                    }
                    .disabled(spaceRepo.selectedSpace == nil)

                    Button {
                        editorTarget = PadNoteEditorTarget()
                    } label: {
                        Label("notes.view.action.addNote", systemImage: "plus")
                    }
                    .disabled(spaceRepo.selectedSpace == nil)
                }
            }
        } else {
            ProgressView("notes.view.loading")
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let note = selectedNote {
            PadNoteDetailView(
                note: note,
                presentationMode: .embedded,
                onEdit: {
                    editorTarget = PadNoteEditorTarget(note: note)
                },
                showsEmbeddedHeader: false
            )
        } else if noteStore != nil {
            ContentUnavailableView(
                "Wybierz notatkę",
                systemImage: "sidebar.left",
                description: Text("Wybierz notatkę z lewej kolumny, aby zobaczyć szczegóły.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ProgressView("notes.detail.loading")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var folderPickerBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    selectedFolderId = nil
                    if selectedNoteId == nil {
                        selectedNoteId = filteredNotes.first?.id
                    }
                } label: {
                    Text("notes.filter.all")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selectedFolderId == nil ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                ForEach(noteStore?.folders ?? []) { folder in
                    Button {
                        selectedFolderId = folder.id
                        if !filteredNotes.contains(where: { $0.id == selectedNoteId }) {
                            selectedNoteId = filteredNotes.first?.id
                        }
                    } label: {
                        Text(folder.name)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedFolderId == folder.id ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top, 4)
        }
        .padding(.bottom, 8)
        .background(Color.systemBackground)
        .overlay(alignment: .bottom) {
            Divider()
                .opacity(0.35)
        }
    }

    private var notesFilterIndicator: some View {
        Image(systemName: selectedFolderId == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
            .font(.title3)
            .foregroundStyle(selectedFolderId == nil ? Color.secondary : Color.accentColor)
            .accessibilityLabel("Filtr folderów")
    }

    private func sidebarRow(for note: Note) -> some View {
        PadNoteSidebarRow(note: note)
            .tag(note.id)
            .contextMenu {
                Button {
                    editorTarget = PadNoteEditorTarget(note: note)
                } label: {
                    Label("common.edit", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    Task {
                        await noteStore?.deleteNote(note, actor: authRepo.currentUser?.id)
                        if selectedNoteId == note.id {
                            selectedNoteId = filteredNotes.first?.id
                        }
                    }
                } label: {
                    Label("common.delete", systemImage: "trash")
                }
            }
    }

    private var selectedNote: Note? {
        guard let selectedNoteId else { return nil }
        return noteStore?.notes.first(where: { $0.id == selectedNoteId })
    }

    private var filteredNotes: [Note] {
        let notes = noteStore?.notes.sorted {
            if $0.isPinnedValue != $1.isPinnedValue {
                return $0.isPinnedValue && !$1.isPinnedValue
            }
            return $0.updatedAt > $1.updatedAt
        } ?? []

        return notes.filter { note in
            let matchesFolder = selectedFolderId == nil || note.folderId == selectedFolderId
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty || noteMatchesSearch(note, query: query)
            return matchesFolder && matchesSearch
        }
    }

    private var pinnedNotes: [Note] {
        filteredNotes.filter(\.isPinnedValue)
    }

    private var datedSections: [PadNoteDaySection] {
        let notes = filteredNotes.filter { !$0.isPinnedValue }
        let grouped = Dictionary(grouping: notes) { Calendar.current.startOfDay(for: $0.updatedAt) }

        return grouped
            .map { date, notes in
                PadNoteDaySection(
                    date: date,
                    notes: notes.sorted { $0.updatedAt > $1.updatedAt }
                )
            }
            .sorted { $0.date > $1.date }
    }

    private func noteMatchesSearch(_ note: Note, query: String) -> Bool {
        let normalizedQuery = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let haystacks = [
            note.title,
            note.previewText,
            note.savedPlaceName ?? "",
            note.relatedLocationLabel ?? "",
            note.attachedLinkURL ?? "",
            note.resolvedTags.joined(separator: " ")
        ]

        return haystacks.contains {
            $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .contains(normalizedQuery)
        }
    }

    @MainActor
    private func setupStoreIfNeeded(performRemoteRefresh: Bool = true) async {
        guard noteStore == nil else { return }
        let repository = NoteRepository(client: SupabaseConfig.client, context: modelContext)
        let store = NoteStore(modelContext: modelContext, repository: repository)
        noteStore = store
        store.setSpace(spaceRepo.selectedSpace?.id)

        if selectedNoteId == nil {
            selectedNoteId = filteredNotes.first?.id ?? store.notes.first?.id
        }

        if performRemoteRefresh && !isPreview {
            await store.refreshRemote()
            if selectedNoteId == nil {
                selectedNoteId = filteredNotes.first?.id ?? store.notes.first?.id
            }
        }
    }

    @MainActor
    private func refreshNotes() async {
        await noteStore?.syncPending()
        await noteStore?.refreshRemote()
        loadReferences()
        if selectedNoteId == nil {
            selectedNoteId = filteredNotes.first?.id
        }
    }

    private func loadReferences() {
        guard let spaceId = spaceRepo.selectedSpace?.id else {
            missions = []
            incidents = []
            people = []
            recentLocations = []
            return
        }
        do {
            missions = try modelContext.fetch(
                FetchDescriptor<Mission>(
                    predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                    sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
                )
            )
            incidents = try modelContext.fetch(
                FetchDescriptor<Incident>(
                    predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                    sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
                )
            )
            recentLocations = try modelContext.fetch(
                FetchDescriptor<LocationPing>(
                    predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                    sortBy: [SortDescriptor(\.recordedAt, order: .reverse)]
                )
            )
            people = authRepo.currentUser?
                .memberships
                .filter { $0.spaceId == spaceId }
                .compactMap(\.user) ?? []
        } catch {
            Log.dbError("PadNotesSidebarWorkspace.loadReferences (SwiftData fetch)", error)
            missions = []
            incidents = []
            people = []
            recentLocations = []
        }
    }

    private func savedPlaces() -> [SavedPlace] {
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

private struct PadNoteSidebarRow: View {
    let note: Note

    private var footerText: String? {
        var items = note.resolvedTags
        if let savedPlaceName = note.savedPlaceName, !savedPlaceName.isEmpty {
            items.append(savedPlaceName)
        }
        return items.isEmpty ? nil : items.joined(separator: " • ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                Text(note.title)
                    .font(.headline)
                    .lineLimit(2)

                Spacer(minLength: 8)

                if note.isPinnedValue {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !note.previewText.isEmpty {
                Text(note.previewText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                Text(note.updatedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let footerText {
                    Text(footerText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct PadNoteDaySection: Identifiable {
    let date: Date
    let notes: [Note]

    var id: Date { date }

    var title: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Dzisiaj"
        }

        if calendar.isDateInYesterday(date) {
            return "Wczoraj"
        }

        return date.formatted(.dateTime.day().month(.wide).year())
    }
}

private struct PadNoteEditorTarget: Identifiable, Hashable {
    let id = UUID()
    let note: Note?

    init(note: Note? = nil) {
        self.note = note
    }
}

#endif
