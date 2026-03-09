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
                        actorId: authRepo.currentUser?.id
                    )
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
                        actorId: authRepo.currentUser?.id
                    )
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
                        Button("notes.folder.action.create") {
                            Task {
                                let value = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !value.isEmpty else { return }
                                await noteStore?.addFolder(name: value, actor: authRepo.currentUser?.id)
                                newFolderName = ""
                                showFolderCreator = false
                            }
                        }
                        .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .navigationTitle("notes.folder.title.new")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("common.cancel") { showFolderCreator = false }
                        }
                    }
                }
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
        guard let selectedFolderId else { return noteStore?.notes ?? [] }
        return (noteStore?.notes ?? []).filter { $0.folderId == selectedFolderId }
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
}

private struct NoteDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let note: Note
    let onEdit: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(note.title)
                        .font(.title2.bold())

                    if !note.content.isEmpty {
                        Text(note.content)
                            .font(.body)
                    }

                    if let url = note.attachedLinkURL, !url.isEmpty, let validURL = URL(string: url) {
                        Link(destination: validURL) {
                            Label(url, systemImage: "link")
                                .lineLimit(1)
                        }
                    }

                    if note.relatedIncidentId != nil {
                        Label("notes.view.badge.incident", systemImage: "bolt.horizontal")
                            .font(.caption)
                    }

                    if note.relatedLocationLatitude != nil && note.relatedLocationLongitude != nil {
                        Label(note.relatedLocationLabel ?? String(localized: "notes.view.badge.location"), systemImage: "location")
                            .font(.caption)
                    }

                    Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle("notes.view.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onEdit()
                    } label: {
                        Label("common.edit", systemImage: "pencil")
                    }
                }
            }
        }
    }
}

private struct NoteEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let noteStore: NoteStore
    let note: Note?
    let folders: [NoteFolder]
    let incidents: [Incident]
    let locations: [LocationPing]
    let actorId: UUID?

    @State private var title: String
    @State private var content: String
    @State private var selectedFolderId: UUID?
    @State private var attachedLinkURL: String
    @State private var selectedIncidentId: UUID?
    @State private var selectedLocationId: UUID?
    @State private var isSaving = false

    init(
        noteStore: NoteStore,
        note: Note? = nil,
        folders: [NoteFolder],
        incidents: [Incident],
        locations: [LocationPing],
        actorId: UUID?
    ) {
        self.noteStore = noteStore
        self.note = note
        self.folders = folders
        self.incidents = incidents
        self.locations = locations
        self.actorId = actorId
        _title = State(initialValue: note?.title ?? "")
        _content = State(initialValue: note?.content ?? "")
        _selectedFolderId = State(initialValue: note?.folderId)
        _attachedLinkURL = State(initialValue: note?.attachedLinkURL ?? "")
        _selectedIncidentId = State(initialValue: note?.relatedIncidentId)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("notes.editor.field.title", text: $title)
                TextField("notes.editor.field.content", text: $content, axis: .vertical)
                Picker("notes.editor.field.folder", selection: $selectedFolderId) {
                    Text("notes.folder.none").tag(UUID?.none)
                    ForEach(folders) { folder in
                        Text(folder.name).tag(UUID?.some(folder.id))
                    }
                }
                TextField("notes.editor.field.linkUrl", text: $attachedLinkURL)
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif
                    .autocorrectionDisabled()

                Picker("notes.editor.field.incident", selection: $selectedIncidentId) {
                    Text("common.none").tag(UUID?.none)
                    ForEach(incidents) { incident in
                        Text(incident.title).tag(UUID?.some(incident.id))
                    }
                }

                Picker("notes.editor.field.location", selection: $selectedLocationId) {
                    Text("common.none").tag(UUID?.none)
                    ForEach(locations) { location in
                        Text("\(location.userDisplayName) · \(location.recordedAt.formatted(date: .abbreviated, time: .shortened))")
                            .tag(UUID?.some(location.id))
                    }
                }

                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text(note == nil ? "notes.editor.action.create" : "common.saveChanges")
                    }
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            }
            .navigationTitle(note == nil ? "notes.editor.title.new" : "notes.editor.title.edit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
        }
    }

    /// Persists note changes and closes sheet when operation succeeds.
    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let location = locations.first { $0.id == selectedLocationId }
        let cleanLink = attachedLinkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if let note {
            await noteStore.updateNote(
                note,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                content: content,
                folderId: selectedFolderId,
                attachedLinkURL: cleanLink.isEmpty ? nil : cleanLink,
                relatedIncidentId: selectedIncidentId,
                relatedLocationLatitude: location?.latitude,
                relatedLocationLongitude: location?.longitude,
                relatedLocationLabel: location?.userDisplayName,
                actor: actorId
            )
        } else {
            await noteStore.addNote(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                content: content,
                folderId: selectedFolderId,
                attachedLinkURL: cleanLink.isEmpty ? nil : cleanLink,
                relatedIncidentId: selectedIncidentId,
                relatedLocationLatitude: location?.latitude,
                relatedLocationLongitude: location?.longitude,
                relatedLocationLabel: location?.userDisplayName,
                actor: actorId
            )
        }
        dismiss()
    }
}

#Preview("notes.view.title") {
    let schema = Schema([
        UserProfile.self,
        Space.self,
        SpaceMembership.self,
        Note.self,
        NoteFolder.self,
        Incident.self,
        LocationPing.self
    ])
    let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext

    let user = UserProfile(id: UUID(), email: "preview@ufo.app", fullName: "Preview User", role: "admin")
    let space = Space(id: UUID(), name: "Family Crew", inviteCode: "UFO123")
    context.insert(user)
    context.insert(space)
    context.insert(SpaceMembership(user: user, space: space, role: "admin"))
    context.insert(Note(spaceId: space.id, title: "Trip note", content: "Remember passports", attachedLinkURL: "https://example.com", createdBy: user.id))
    context.insert(NoteFolder(spaceId: space.id, name: "Work", createdBy: user.id))
    context.insert(Incident(spaceId: space.id, title: "Storm", incidentDescription: "Strong wind", occurrenceDate: .now, createdBy: user.id))
    context.insert(LocationPing(spaceId: space.id, userId: user.id, userDisplayName: "Preview User", latitude: 52.22, longitude: 21.01))
    do {
        try context.save()
    } catch {
        Log.dbError("Notes preview context.save", error)
    }

    let authRepo = AuthRepository(client: SupabaseConfig.client, isLoggedIn: true, currentUser: user)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    spaceRepo.selectedSpace = space

    return NotesView()
        .environment(authRepo)
        .environment(spaceRepo)
        .modelContainer(container)
}
