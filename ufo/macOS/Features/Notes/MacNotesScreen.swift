#if os(macOS)

import SwiftUI
import SwiftData

struct MacNotesScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo

    @State private var noteStore: NoteStore?
    @State private var editorTarget: MacNoteEditorTarget?
    @State private var viewingNote: Note?
    @State private var missions: [Mission] = []
    @State private var incidents: [Incident] = []
    @State private var people: [UserProfile] = []
    @State private var recentLocations: [LocationPing] = []
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
        Group {
            List {
                if let error = noteStore?.lastErrorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if !pinnedNotes.isEmpty {
                    Section("Pinned") {
                        ForEach(pinnedNotes) { note in
                            noteRow(for: note)
                        }
                    }
                }

                ForEach(datedSections) { section in
                    Section(section.title) {
                        ForEach(section.notes) { note in
                            noteRow(for: note)
                        }
                    }
                }
            }
            .appPrimaryListChrome()
        }
        .appScreenBackground()
        .navigationTitle("notes.view.title")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    showFolderCreator = true
                } label: {
                    Label("notes.view.action.addFolder", systemImage: "folder.badge.plus")
                }
                .disabled(noteStore == nil || spaceRepo.selectedSpace == nil)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    editorTarget = MacNoteEditorTarget()
                } label: {
                    Label("notes.view.action.addNote", systemImage: "plus")
                }
                .disabled(noteStore == nil || spaceRepo.selectedSpace == nil)
            }
        }
        .refreshable {
            await refreshNotes()
        }
        .safeAreaInset(edge: .top) {
            folderPickerBar
        }
        .navigationDestination(item: $viewingNote) { note in
            MacNoteDetailView(
                note: note,
                presentationMode: .embedded,
                onEdit: {
                    viewingNote = nil
                    DispatchQueue.main.async {
                        editorTarget = MacNoteEditorTarget(note: note)
                    }
                }
            )
            .frame(minWidth: 620, minHeight: 620)
        }
        .navigationDestination(item: $editorTarget) { target in
            if let noteStore {
                MacNoteEditorView(
                    noteStore: noteStore,
                    note: target.note,
                    folders: noteStore.folders,
                    missions: missions,
                    incidents: incidents,
                    people: people,
                    locations: recentLocations,
                    savedPlaces: savedPlaces(),
                    actorId: authRepo.currentUser?.id
                )
                .frame(minWidth: 720, minHeight: 720)
            }
        }
        .navigationDestination(isPresented: $showFolderCreator) {
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
            .frame(minWidth: 520, minHeight: 320)
        }
        .task {
            await setupStoreIfNeeded(performRemoteRefresh: !autoPresentAdd)
            loadReferences()
            if autoPresentAdd && !didAutoPresentAdd && noteStore != nil {
                didAutoPresentAdd = true
                try? await Task.sleep(for: .milliseconds(150))
                editorTarget = MacNoteEditorTarget()
            }
        }
        .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
            noteStore?.setSpace(newValue)
            Task { await noteStore?.refreshRemote() }
            loadReferences()
        }
        .safeAreaInset(edge: .bottom) {
            FeatureBottomSearchBar(text: $searchText, prompt: "Szukaj notatek")
        }
    }

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
        .padding(.bottom, 8)
        .appSurfaceBackground()
        .overlay(alignment: .bottom) {
            Divider()
                .opacity(0.35)
        }
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

    private var datedSections: [MacNoteDaySection] {
        let notes = filteredNotes.filter { !$0.isPinnedValue }
        let grouped = Dictionary(grouping: notes) { Calendar.current.startOfDay(for: $0.updatedAt) }

        return grouped
            .map { date, notes in
                MacNoteDaySection(
                    date: date,
                    notes: notes.sorted { $0.updatedAt > $1.updatedAt }
                )
            }
            .sorted { $0.date > $1.date }
    }

    @ViewBuilder
    private func noteRow(for note: Note) -> some View {
        Button {
            viewingNote = note
        } label: {
            MacNoteCardView(note: note)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .contextMenu {
            Button {
                editorTarget = MacNoteEditorTarget(note: note)
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
        if performRemoteRefresh && !isPreview {
            await store.refreshRemote()
        }
    }

    @MainActor
    private func refreshNotes() async {
        await noteStore?.syncPending()
        await noteStore?.refreshRemote()
        loadReferences()
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
            Log.dbError("MacNotesScreen.loadReferences (SwiftData fetch)", error)
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

private struct MacNoteCardView: View {
    let note: Note

    private var footerItems: [String] {
        var items = note.resolvedTags

        if let savedPlaceName = note.savedPlaceName, !savedPlaceName.isEmpty {
            items.append(savedPlaceName)
        }

        if let url = note.attachedLinkURL, !url.isEmpty {
            items.append(String(localized: "notes.view.badge.link"))
        }

        if note.relatedIncidentId != nil {
            items.append(String(localized: "notes.view.badge.incident"))
        }

        if note.relatedLocationLatitude != nil && note.relatedLocationLongitude != nil {
            items.append(note.relatedLocationLabel ?? String(localized: "notes.view.badge.location"))
        }

        return items
    }

    private var previewBodyText: String {
        let value = note.previewText
        return value.isEmpty ? String(localized: "Brak dodatkowego tekstu") : value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Text(note.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 12)

                if note.isPinnedValue {
                    Image(systemName: "pin.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Text(previewBodyText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .lineLimit(2)

            if !footerItems.isEmpty {
                HStack(alignment: .bottom, spacing: 12) {
                    Text(footerItems.joined(separator: " • "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.cardBackground)
        )
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct MacNoteDaySection: Identifiable {
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

private struct MacNoteEditorTarget: Identifiable, Hashable {
    let id = UUID()
    let note: Note?

    init(note: Note? = nil) {
        self.note = note
    }
}

#endif
