import SwiftUI
import SwiftData

struct NotesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo

    @State private var noteStore: NoteStore?
    @State private var isAddingNote = false
    @State private var editingNote: Note?
    @State private var viewingNote: Note?
    @State private var incidents: [Incident] = []
    @State private var recentLocations: [LocationPing] = []
    @State private var selectedFolderId: UUID?
    @State private var newFolderName = ""
    @State private var showFolderCreator = false

    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    var body: some View {
        NavigationStack {
            List {
                if let error = noteStore?.lastErrorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                ForEach(filteredNotes) { note in
                    Button {
                        viewingNote = note
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(note.title)
                                .font(.headline)
                            if !note.content.isEmpty {
                                Text(note.content)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 10) {
                                if note.isPinnedValue {
                                    Label("Pinned", systemImage: "pin.fill")
                                        .font(.caption)
                                }
                                if let url = note.attachedLinkURL, !url.isEmpty {
                                    Label("notes.view.badge.link", systemImage: "link")
                                        .font(.caption)
                                }
                                if note.relatedIncidentId != nil {
                                    Label("notes.view.badge.incident", systemImage: "bolt.horizontal")
                                        .font(.caption)
                                }
                                if note.relatedLocationLatitude != nil && note.relatedLocationLongitude != nil {
                                    Label(note.relatedLocationLabel ?? String(localized: "notes.view.badge.location"), systemImage: "location")
                                        .font(.caption)
                                }
                            }
                            .foregroundStyle(.secondary)
                            if !note.resolvedTags.isEmpty {
                                Text(note.resolvedTags.joined(separator: " • "))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if let savedPlaceName = note.savedPlaceName, !savedPlaceName.isEmpty {
                                Label(savedPlaceName, systemImage: "mappin.and.ellipse")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            editingNote = note
                        } label: {
                            Label("common.edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            Task { await noteStore?.deleteNote(note, actor: authRepo.currentUser?.id) }
                        } label: {
                            Label("common.delete", systemImage: "trash")
                        }
                    }
                }
                .onDelete { offsets in
                    let values = offsets.map { filteredNotes[$0] }
                    Task {
                        for note in values {
                            await noteStore?.deleteNote(note, actor: authRepo.currentUser?.id)
                        }
                    }
                }
            }
            .navigationTitle("notes.view.title")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showFolderCreator = true
                    } label: {
                        Label("notes.view.action.addFolder", systemImage: "folder.badge.plus")
                    }
                    .disabled(noteStore == nil || spaceRepo.selectedSpace == nil)
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingNote = true
                    } label: {
                        Label("notes.view.action.addNote", systemImage: "plus")
                    }
                    .disabled(noteStore == nil || spaceRepo.selectedSpace == nil)
                }

                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await noteStore?.syncPending() }
                    } label: {
                        Label("common.sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                folderPickerBar
            }
            .sheet(isPresented: $isAddingNote) {
                if let noteStore {
                    NoteEditorView(
                        noteStore: noteStore,
                        folders: noteStore.folders,
                        incidents: incidents,
                        locations: recentLocations,
                        savedPlaces: savedPlaces(),
                        actorId: authRepo.currentUser?.id
                    )
                    #if os(iOS)
                    .presentationDetents([.medium, .large])
                    #endif
                }
            }
            .sheet(item: $editingNote) { note in
                if let noteStore {
                    NoteEditorView(
                        noteStore: noteStore,
                        note: note,
                        folders: noteStore.folders,
                        incidents: incidents,
                        locations: recentLocations,
                        savedPlaces: savedPlaces(),
                        actorId: authRepo.currentUser?.id
                    )
                    #if os(iOS)
                    .presentationDetents([.medium, .large])
                    #endif
                }
            }
            .sheet(item: $viewingNote) { note in
                NoteDetailView(
                    note: note,
                    onEdit: {
                        viewingNote = nil
                        DispatchQueue.main.async {
                            editingNote = note
                        }
                    }
                )
            }
            .sheet(isPresented: $showFolderCreator) {
                NavigationStack {
                    Form {
                        TextField("notes.folder.field.name", text: $newFolderName)
                    }
                    .navigationTitle("notes.folder.title.new")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("common.cancel") { showFolderCreator = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button {
                                Task {
                                    let value = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !value.isEmpty else { return }
                                    await noteStore?.addFolder(name: value, actor: authRepo.currentUser?.id)
                                    newFolderName = ""
                                    showFolderCreator = false
                                }
                            } label: {
                                Image(systemName: "checkmark")
                            }
                            .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                #if os(iOS)
                .presentationDetents([.medium, .large])
                #endif
            }
            .task {
                await setupStoreIfNeeded()
                loadReferences()
            }
            .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
                noteStore?.setSpace(newValue)
                Task { await noteStore?.refreshRemote() }
                loadReferences()
            }
        }
    }

    /// Renders horizontal folder selector used to filter note list.
    private var folderPickerBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    selectedFolderId = nil
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
    }

    /// Returns notes filtered by currently selected folder.
    private var filteredNotes: [Note] {
        let notes = noteStore?.notes.sorted {
            if $0.isPinnedValue != $1.isPinnedValue {
                return $0.isPinnedValue && !$1.isPinnedValue
            }
            return $0.updatedAt > $1.updatedAt
        } ?? []
        guard let selectedFolderId else { return notes }
        return notes.filter { $0.folderId == selectedFolderId }
    }

    /// Initializes note store once and performs first remote refresh.
    @MainActor
    private func setupStoreIfNeeded() async {
        guard noteStore == nil else { return }
        let repository = NoteRepository(client: SupabaseConfig.client, context: modelContext)
        let store = NoteStore(modelContext: modelContext, repository: repository)
        noteStore = store
        store.setSpace(spaceRepo.selectedSpace?.id)
        if !isPreview {
            await store.refreshRemote()
        }
    }

    /// Loads incidents and locations used by note attachments.
    private func loadReferences() {
        guard let spaceId = spaceRepo.selectedSpace?.id else {
            incidents = []
            recentLocations = []
            return
        }
        do {
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
        } catch {
            Log.dbError("Notes.loadReferences (SwiftData fetch)", error)
            incidents = []
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





#Preview("notes.view.title") {
    let preview = NotesPreviewFactory.make()
    let authRepo = AuthRepository(client: SupabaseConfig.client, isLoggedIn: true, currentUser: preview.user)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    spaceRepo.selectedSpace = preview.space

    return NotesView()
        .environment(authRepo)
        .environment(spaceRepo)
        .modelContainer(preview.container)
}
