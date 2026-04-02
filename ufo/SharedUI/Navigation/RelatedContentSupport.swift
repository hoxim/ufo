import SwiftUI
import SwiftData
import MapKit
#if os(iOS)
import UIKit
#endif

enum RelatedContentRoute: Hashable, Identifiable {
    case mission(UUID)
    case incident(UUID)
    case note(UUID)
    case list(UUID)
    case place(UUID)

    var id: String {
        switch self {
        case .mission(let id):
            return "mission-\(id.uuidString)"
        case .incident(let id):
            return "incident-\(id.uuidString)"
        case .note(let id):
            return "note-\(id.uuidString)"
        case .list(let id):
            return "list-\(id.uuidString)"
        case .place(let id):
            return "place-\(id.uuidString)"
        }
    }
}

enum DetailPresentationMode {
    case modal
    case embedded
}

struct RelatedContentSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            VStack(spacing: 10) {
                content()
            }
        }
    }
}

struct RelatedContentButton: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    var tint: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(tint)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct OpenedFromBadge: View {
    let title: String

    var body: some View {
        Label("Opened from \(title)", systemImage: "arrow.turn.down.left")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.12), in: Capsule())
    }
}

struct RelatedContentDestinationView: View {
    let route: RelatedContentRoute
    var originLabel: String? = nil

    var body: some View {
        switch route {
        case .mission(let id):
            MissionDetailContainerView(missionId: id, openedFromLabel: originLabel)
        case .incident(let id):
            IncidentDetailContainerView(incidentId: id, openedFromLabel: originLabel)
        case .note(let id):
            NoteDetailContainerView(noteId: id, openedFromLabel: originLabel)
        case .list(let id):
            SharedListDetailContainerView(listId: id, openedFromLabel: originLabel)
        case .place(let id):
            SavedPlaceDetailView(placeId: id, openedFromLabel: originLabel)
        }
    }
}

struct MissionDetailContainerView: View {
    @Environment(\.modelContext) private var modelContext

    let missionId: UUID
    var openedFromLabel: String? = nil

    var body: some View {
        if let mission = resolveMission() {
            platformMissionDetailView(for: mission)
        } else {
            ContentUnavailableView("Mission unavailable", systemImage: "flag.slash")
        }
    }

    private func resolveMission() -> Mission? {
        try? modelContext.fetch(
            FetchDescriptor<Mission>(
                predicate: #Predicate { $0.id == missionId && $0.deletedAt == nil }
            )
        ).first
    }

    @ViewBuilder
    private func platformMissionDetailView(for mission: Mission) -> some View {
        #if os(macOS)
        MacMissionDetailView(
            mission: mission,
            presentationMode: .embedded,
            openedFromLabel: openedFromLabel
        )
        #elseif os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            PadMissionDetailView(
                mission: mission,
                presentationMode: .embedded,
                openedFromLabel: openedFromLabel
            )
        } else {
            PhoneMissionDetailView(
                mission: mission,
                presentationMode: .embedded,
                openedFromLabel: openedFromLabel
            )
        }
        #else
        EmptyView()
        #endif
    }
}

struct IncidentDetailContainerView: View {
    @Environment(\.modelContext) private var modelContext

    let incidentId: UUID
    var openedFromLabel: String? = nil

    var body: some View {
        if let incident = resolveIncident() {
            platformIncidentDetailView(for: incident)
        } else {
            ContentUnavailableView("Incident unavailable", systemImage: "exclamationmark.triangle")
        }
    }

    private func resolveIncident() -> Incident? {
        try? modelContext.fetch(
            FetchDescriptor<Incident>(
                predicate: #Predicate { $0.id == incidentId && $0.deletedAt == nil }
            )
        ).first
    }

    @ViewBuilder
    private func platformIncidentDetailView(for incident: Incident) -> some View {
        #if os(macOS)
        MacIncidentDetailView(
            incident: incident,
            presentationMode: .embedded,
            openedFromLabel: openedFromLabel
        )
        #elseif os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            PadIncidentDetailView(
                incident: incident,
                presentationMode: .embedded,
                openedFromLabel: openedFromLabel
            )
        } else {
            PhoneIncidentDetailView(
                incident: incident,
                presentationMode: .embedded,
                openedFromLabel: openedFromLabel
            )
        }
        #else
        EmptyView()
        #endif
    }
}

struct NoteDetailContainerView: View {
    @Environment(\.modelContext) private var modelContext

    let noteId: UUID
    var openedFromLabel: String? = nil

    var body: some View {
        if let note = resolveNote() {
            platformNoteDetailView(for: note)
        } else {
            ContentUnavailableView("Note unavailable", systemImage: "note.text.badge.plus")
        }
    }

    private func resolveNote() -> Note? {
        try? modelContext.fetch(
            FetchDescriptor<Note>(
                predicate: #Predicate { $0.id == noteId && $0.deletedAt == nil }
            )
        ).first
    }

    @ViewBuilder
    private func platformNoteDetailView(for note: Note) -> some View {
        #if os(macOS)
        MacNoteDetailView(
            note: note,
            presentationMode: .embedded,
            openedFromLabel: openedFromLabel
        )
        #elseif os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            PadNoteDetailView(
                note: note,
                presentationMode: .embedded,
                openedFromLabel: openedFromLabel
            )
        } else {
            PhoneNoteDetailView(
                note: note,
                presentationMode: .embedded,
                openedFromLabel: openedFromLabel
            )
        }
        #else
        EmptyView()
        #endif
    }
}

struct SharedListDetailContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo

    @State private var store: SharedListStore?

    let listId: UUID
    var openedFromLabel: String? = nil

    var body: some View {
        Group {
            if let store {
                platformListDetailView(store: store)
            } else {
                ProgressView("Loading list")
            }
        }
        .task {
            await setupStoreIfNeeded()
        }
        .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
            store?.setSpace(newValue)
        }
    }

    @MainActor
    private func setupStoreIfNeeded() async {
        guard store == nil else { return }
        let repo = SharedListRepository(client: SupabaseConfig.client, context: modelContext)
        let createdStore = SharedListStore(modelContext: modelContext, repository: repo)
        createdStore.setSpace(spaceRepo.selectedSpace?.id)
        store = createdStore
    }

    @ViewBuilder
    private func platformListDetailView(store: SharedListStore) -> some View {
        #if os(macOS)
        MacListDetailView(
            store: store,
            listId: listId,
            actorId: authRepo.currentUser?.id,
            openedFromLabel: openedFromLabel
        )
        #elseif os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            PadListDetailView(
                store: store,
                listId: listId,
                actorId: authRepo.currentUser?.id,
                openedFromLabel: openedFromLabel
            )
        } else {
            PhoneListDetailView(
                store: store,
                listId: listId,
                actorId: authRepo.currentUser?.id,
                openedFromLabel: openedFromLabel
            )
        }
        #else
        EmptyView()
        #endif
    }
}

struct QuickCreateNoteSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthRepository.self) private var authRepo
    @Environment(SpaceRepository.self) private var spaceRepo

    @State private var store: NoteStore?

    let prefillLinkedEntityType: NoteLinkedEntityType?
    let prefillLinkedEntityId: UUID?
    let prefillSavedPlaceId: UUID?
    let prefillSelectedIncidentId: UUID?
    let originLabel: String?
    var onCreated: ((UUID) -> Void)? = nil

    var body: some View {
        Group {
            if let store {
                platformNoteEditorView(store: store)
            } else {
                ProgressView("Loading note editor")
            }
        }
        .task {
            await setupStoreIfNeeded()
        }
    }

    @MainActor
    private func setupStoreIfNeeded() async {
        guard store == nil else { return }
        let repository = NoteRepository(client: SupabaseConfig.client, context: modelContext)
        let createdStore = NoteStore(modelContext: modelContext, repository: repository)
        createdStore.setSpace(spaceRepo.selectedSpace?.id)
        store = createdStore
    }

    @ViewBuilder
    private func platformNoteEditorView(store: NoteStore) -> some View {
        NavigationStack {
            #if os(macOS)
            MacNoteEditorView(
                noteStore: store,
                folders: store.folders,
                missions: missions,
                incidents: incidents,
                people: people,
                locations: locations,
                savedPlaces: savedPlaces,
                actorId: authRepo.currentUser?.id,
                prefillLinkedEntityType: prefillLinkedEntityType,
                prefillLinkedEntityId: prefillLinkedEntityId,
                prefillSavedPlaceId: prefillSavedPlaceId,
                prefillSelectedIncidentId: prefillSelectedIncidentId,
                originLabel: originLabel,
                onSaved: onCreated
            )
            #elseif os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad {
                PadNoteEditorView(
                    noteStore: store,
                    folders: store.folders,
                    missions: missions,
                    incidents: incidents,
                    people: people,
                    locations: locations,
                    savedPlaces: savedPlaces,
                    actorId: authRepo.currentUser?.id,
                    prefillLinkedEntityType: prefillLinkedEntityType,
                    prefillLinkedEntityId: prefillLinkedEntityId,
                    prefillSavedPlaceId: prefillSavedPlaceId,
                    prefillSelectedIncidentId: prefillSelectedIncidentId,
                    originLabel: originLabel,
                    onSaved: onCreated
                )
            } else {
                PhoneNoteEditorView(
                    noteStore: store,
                    folders: store.folders,
                    missions: missions,
                    incidents: incidents,
                    people: people,
                    locations: locations,
                    savedPlaces: savedPlaces,
                    actorId: authRepo.currentUser?.id,
                    prefillLinkedEntityType: prefillLinkedEntityType,
                    prefillLinkedEntityId: prefillLinkedEntityId,
                    prefillSavedPlaceId: prefillSavedPlaceId,
                    prefillSelectedIncidentId: prefillSelectedIncidentId,
                    originLabel: originLabel,
                    onSaved: onCreated
                )
            }
            #else
            EmptyView()
            #endif
        }
    }

    private var missions: [Mission] {
        guard let spaceId = spaceRepo.selectedSpace?.id else { return [] }
        return fetch(
            FetchDescriptor<Mission>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )
    }

    private var incidents: [Incident] {
        guard let spaceId = spaceRepo.selectedSpace?.id else { return [] }
        return fetch(
            FetchDescriptor<Incident>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )
    }

    private var locations: [LocationPing] {
        guard let spaceId = spaceRepo.selectedSpace?.id else { return [] }
        return fetch(
            FetchDescriptor<LocationPing>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.recordedAt, order: .reverse)]
            )
        )
    }

    private var savedPlaces: [SavedPlace] {
        guard let spaceId = spaceRepo.selectedSpace?.id else { return [] }
        return fetch(
            FetchDescriptor<SavedPlace>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.name, order: .forward)]
            )
        )
    }

    private var people: [UserProfile] {
        guard let spaceId = spaceRepo.selectedSpace?.id else { return [] }
        return authRepo.currentUser?
            .memberships
            .filter { $0.spaceId == spaceId }
            .compactMap(\.user) ?? []
    }

    private func fetch<T>(_ descriptor: FetchDescriptor<T>) -> [T] where T: PersistentModel {
        (try? modelContext.fetch(descriptor)) ?? []
    }

}

struct QuickCreateMissionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthRepository.self) private var authRepo
    @Environment(SpaceRepository.self) private var spaceRepo

    @State private var store: MissionStore?

    let initialSavedPlaceId: UUID?
    let initialRelatedListId: UUID?
    let originLabel: String?
    let onCreated: (UUID) -> Void

    init(
        initialSavedPlaceId: UUID? = nil,
        initialRelatedListId: UUID? = nil,
        originLabel: String? = nil,
        onCreated: @escaping (UUID) -> Void
    ) {
        self.initialSavedPlaceId = initialSavedPlaceId
        self.initialRelatedListId = initialRelatedListId
        self.originLabel = originLabel
        self.onCreated = onCreated
    }

    var body: some View {
        Group {
            if let store {
                platformMissionEditor(store: store)
            } else {
                ProgressView("Loading mission editor")
            }
        }
        .task {
            await setupStoreIfNeeded()
        }
    }

    @MainActor
    private func setupStoreIfNeeded() async {
        guard store == nil else { return }
        let repository = MissionRepository(client: SupabaseConfig.client, context: modelContext)
        let createdStore = MissionStore(modelContext: modelContext, missionRepository: repository)
        createdStore.setSpace(spaceRepo.selectedSpace?.id)
        store = createdStore
    }

    private var savedPlaces: [SavedPlace] {
        guard let spaceId = spaceRepo.selectedSpace?.id else { return [] }
        return fetch(
            FetchDescriptor<SavedPlace>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.name, order: .forward)]
            )
        )
    }

    private var lists: [SharedList] {
        guard let spaceId = spaceRepo.selectedSpace?.id else { return [] }
        return fetch(
            FetchDescriptor<SharedList>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )
    }

    private var notes: [Note] {
        guard let spaceId = spaceRepo.selectedSpace?.id else { return [] }
        return fetch(
            FetchDescriptor<Note>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )
    }

    private var incidents: [Incident] {
        guard let spaceId = spaceRepo.selectedSpace?.id else { return [] }
        return fetch(
            FetchDescriptor<Incident>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )
    }

    private var people: [UserProfile] {
        guard let spaceId = spaceRepo.selectedSpace?.id else { return [] }
        return authRepo.currentUser?
            .memberships
            .filter { $0.spaceId == spaceId }
            .compactMap(\.user) ?? []
    }

    private func fetch<T>(_ descriptor: FetchDescriptor<T>) -> [T] where T: PersistentModel {
        (try? modelContext.fetch(descriptor)) ?? []
    }

    @ViewBuilder
    private func platformMissionEditor(store: MissionStore) -> some View {
        #if os(macOS)
        MacAddMissionView(
            store: store,
            userId: authRepo.currentUser?.id,
            availableOwners: people,
            availablePlaces: savedPlaces,
            availableLists: lists,
            availableNotes: notes,
            availableIncidents: incidents,
            initialSavedPlaceId: initialSavedPlaceId,
            initialRelatedListId: initialRelatedListId,
            onCreated: onCreated
        )
        #elseif os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            PadAddMissionView(
                store: store,
                userId: authRepo.currentUser?.id,
                availableOwners: people,
                availablePlaces: savedPlaces,
                availableLists: lists,
                availableNotes: notes,
                availableIncidents: incidents,
                initialSavedPlaceId: initialSavedPlaceId,
                initialRelatedListId: initialRelatedListId,
                onCreated: onCreated
            )
        } else {
            PhoneAddMissionView(
                store: store,
                userId: authRepo.currentUser?.id,
                availableOwners: people,
                availablePlaces: savedPlaces,
                availableLists: lists,
                availableNotes: notes,
                availableIncidents: incidents,
                initialSavedPlaceId: initialSavedPlaceId,
                initialRelatedListId: initialRelatedListId,
                onCreated: onCreated
            )
        }
        #else
        EmptyView()
        #endif
    }

}

struct QuickCreateIncidentSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthRepository.self) private var authRepo
    @Environment(SpaceRepository.self) private var spaceRepo

    @State private var store: IncidentStore?

    let initialRelatedMissionId: UUID?
    let initialRelatedListId: UUID?
    let initialRelatedPlaceId: UUID?
    let originLabel: String?
    let onCreated: (UUID) -> Void

    init(
        initialRelatedMissionId: UUID? = nil,
        initialRelatedListId: UUID? = nil,
        initialRelatedPlaceId: UUID? = nil,
        originLabel: String? = nil,
        onCreated: @escaping (UUID) -> Void
    ) {
        self.initialRelatedMissionId = initialRelatedMissionId
        self.initialRelatedListId = initialRelatedListId
        self.initialRelatedPlaceId = initialRelatedPlaceId
        self.originLabel = originLabel
        self.onCreated = onCreated
    }

    var body: some View {
        Group {
            if let store {
                platformIncidentEditor(store: store)
            } else {
                ProgressView("Loading incident editor")
            }
        }
        .task {
            await setupStoreIfNeeded()
        }
    }

    @MainActor
    private func setupStoreIfNeeded() async {
        guard store == nil else { return }
        let repository = IncidentRepository(client: SupabaseConfig.client, context: modelContext)
        let createdStore = IncidentStore(modelContext: modelContext, repository: repository)
        createdStore.setSpace(spaceRepo.selectedSpace?.id)
        store = createdStore
    }

    private var missions: [Mission] {
        guard let spaceId = spaceRepo.selectedSpace?.id else { return [] }
        return fetch(
            FetchDescriptor<Mission>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )
    }

    private var lists: [SharedList] {
        guard let spaceId = spaceRepo.selectedSpace?.id else { return [] }
        return fetch(
            FetchDescriptor<SharedList>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )
    }

    private var savedPlaces: [SavedPlace] {
        guard let spaceId = spaceRepo.selectedSpace?.id else { return [] }
        return fetch(
            FetchDescriptor<SavedPlace>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.name, order: .forward)]
            )
        )
    }

    private func fetch<T>(_ descriptor: FetchDescriptor<T>) -> [T] where T: PersistentModel {
        (try? modelContext.fetch(descriptor)) ?? []
    }

    @ViewBuilder
    private func platformIncidentEditor(store: IncidentStore) -> some View {
        #if os(macOS)
        MacAddIncidentView(
            store: store,
            userId: authRepo.currentUser?.id,
            availableMissions: missions,
            availableLists: lists,
            availablePlaces: savedPlaces,
            initialRelatedMissionId: initialRelatedMissionId,
            initialRelatedListId: initialRelatedListId,
            initialRelatedPlaceId: initialRelatedPlaceId,
            onCreated: onCreated
        )
        #elseif os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            PadAddIncidentView(
                store: store,
                userId: authRepo.currentUser?.id,
                availableMissions: missions,
                availableLists: lists,
                availablePlaces: savedPlaces,
                initialRelatedMissionId: initialRelatedMissionId,
                initialRelatedListId: initialRelatedListId,
                initialRelatedPlaceId: initialRelatedPlaceId,
                onCreated: onCreated
            )
        } else {
            PhoneAddIncidentView(
                store: store,
                userId: authRepo.currentUser?.id,
                availableMissions: missions,
                availableLists: lists,
                availablePlaces: savedPlaces,
                initialRelatedMissionId: initialRelatedMissionId,
                initialRelatedListId: initialRelatedListId,
                initialRelatedPlaceId: initialRelatedPlaceId,
                onCreated: onCreated
            )
        }
        #else
        EmptyView()
        #endif
    }
}

struct QuickCreateLinkedListSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthRepository.self) private var authRepo
    @Environment(SpaceRepository.self) private var spaceRepo

    @State private var store: SharedListStore?

    let initialSavedPlaceId: UUID?
    let originLabel: String?
    let onCreated: (UUID) -> Void

    var body: some View {
        Group {
            if let store {
                platformListEditor(store: store)
            } else {
                ProgressView("Loading list editor")
            }
        }
        .task {
            await setupStoreIfNeeded()
        }
    }

    @MainActor
    private func setupStoreIfNeeded() async {
        guard store == nil else { return }
        let repository = SharedListRepository(client: SupabaseConfig.client, context: modelContext)
        let createdStore = SharedListStore(modelContext: modelContext, repository: repository)
        createdStore.setSpace(spaceRepo.selectedSpace?.id)
        store = createdStore
    }

    private var savedPlaces: [SavedPlace] {
        guard let spaceId = spaceRepo.selectedSpace?.id else { return [] }
        return (try? modelContext.fetch(
            FetchDescriptor<SavedPlace>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.name, order: .forward)]
            )
        )) ?? []
    }

    @ViewBuilder
    private func platformListEditor(store: SharedListStore) -> some View {
        #if os(macOS)
        MacAddListView(
            store: store,
            actorId: authRepo.currentUser?.id,
            availablePlaces: savedPlaces,
            onCreated: onCreated,
            initialSavedPlaceId: initialSavedPlaceId,
            originLabel: originLabel
        )
        #elseif os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            PadAddListView(
                store: store,
                actorId: authRepo.currentUser?.id,
                availablePlaces: savedPlaces,
                onCreated: onCreated,
                initialSavedPlaceId: initialSavedPlaceId,
                originLabel: originLabel
            )
        } else {
            PhoneAddListView(
                store: store,
                actorId: authRepo.currentUser?.id,
                availablePlaces: savedPlaces,
                onCreated: onCreated,
                initialSavedPlaceId: initialSavedPlaceId,
                originLabel: originLabel
            )
        }
        #else
        EmptyView()
        #endif
    }

}

struct QuickAddPlaceSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthRepository.self) private var authRepo
    @Environment(SpaceRepository.self) private var spaceRepo

    let originLabel: String?
    let onCreated: (SavedPlace) -> Void

    var body: some View {
        QuickAddPlaceContent(
            modelContext: modelContext,
            authRepo: authRepo,
            spaceRepo: spaceRepo,
            originLabel: originLabel,
            onCreated: onCreated
        )
    }
}

#if os(macOS)
private struct QuickAddPlaceContent: View {
    let modelContext: ModelContext
    let authRepo: AuthRepository
    let spaceRepo: SpaceRepository
    let originLabel: String?
    let onCreated: (SavedPlace) -> Void

    @State private var viewModel = MacLocationViewModel()

    var body: some View {
        MacAddSavedPlaceSheet(
            viewModel: viewModel,
            actorId: authRepo.currentUser?.id,
            originLabel: originLabel,
            onCreated: onCreated
        )
        .task {
            await viewModel.setup(
                modelContext: modelContext,
                spaceRepo: spaceRepo,
                isPreview: ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            )
        }
        .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
            Task {
                await viewModel.handleSpaceChange(newValue)
            }
        }
    }
}
#elseif os(iOS)
private struct QuickAddPlaceContent: View {
    let modelContext: ModelContext
    let authRepo: AuthRepository
    let spaceRepo: SpaceRepository
    let originLabel: String?
    let onCreated: (SavedPlace) -> Void

    @State private var phoneViewModel = PhoneLocationViewModel()
    @State private var padViewModel = PadLocationViewModel()

    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                PadAddSavedPlaceSheet(
                    viewModel: padViewModel,
                    actorId: authRepo.currentUser?.id,
                    originLabel: originLabel,
                    onCreated: onCreated
                )
                .task {
                    await padViewModel.setup(
                        modelContext: modelContext,
                        spaceRepo: spaceRepo,
                        isPreview: ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
                    )
                }
                .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
                    Task {
                        await padViewModel.handleSpaceChange(newValue)
                    }
                }
            } else {
                PhoneAddSavedPlaceSheet(
                    viewModel: phoneViewModel,
                    actorId: authRepo.currentUser?.id,
                    originLabel: originLabel,
                    onCreated: onCreated
                )
                .task {
                    await phoneViewModel.setup(
                        modelContext: modelContext,
                        spaceRepo: spaceRepo,
                        isPreview: ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
                    )
                }
                .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
                    Task {
                        await phoneViewModel.handleSpaceChange(newValue)
                    }
                }
            }
        }
    }
}
#endif

struct SavedPlaceDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    let placeId: UUID
    var openedFromLabel: String? = nil

    var body: some View {
        if let place = resolvePlace() {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let openedFromLabel {
                        OpenedFromBadge(title: openedFromLabel)
                    }

                    placeHeader(for: place)

                    SavedPlaceDetailMapCard(place: place)

                    if let description = place.placeDescription, !description.isEmpty {
                        detailCard("Description") {
                            Text(description)
                                .font(.body)
                        }
                    }

                    detailCard("Details") {
                        VStack(alignment: .leading, spacing: 14) {
                            SavedPlaceDetailRow(
                                title: "Type",
                                value: place.resolvedCategory.title,
                                systemImage: "tag"
                            )

                            if let address = place.address, !address.isEmpty {
                                SavedPlaceDetailRow(
                                    title: "Address",
                                    value: address,
                                    systemImage: "map"
                                )
                            }

                            SavedPlaceDetailRow(
                                title: "Coordinates",
                                value: "\(place.latitude.formatted(.number.precision(.fractionLength(5)))) , \(place.longitude.formatted(.number.precision(.fractionLength(5))))",
                                systemImage: "location"
                            )

                            SavedPlaceDetailRow(
                                title: "Radius",
                                value: "\(Int(place.radiusMeters)) m",
                                systemImage: "circle.dotted"
                            )
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            openMaps(for: place, directions: false)
                        } label: {
                            Label("Open in Maps", systemImage: "map")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            openMaps(for: place, directions: true)
                        } label: {
                            Label("Navigate", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle(place.name)
            .inlineNavigationTitle()
        } else {
            ContentUnavailableView("Place unavailable", systemImage: "mappin.slash")
        }
    }

    @ViewBuilder
    private func placeHeader(for place: SavedPlace) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: place.iconColorHex ?? "#0F766E").opacity(0.14))
                    .frame(width: 52, height: 52)

                Image(systemName: place.iconName ?? "mappin.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(hex: place.iconColorHex ?? "#0F766E"))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.title2.bold())
                Text(place.resolvedCategory.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func detailCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.secondarySystemBackgroundAdaptive, in: RoundedRectangle(cornerRadius: 18))
    }

    private func resolvePlace() -> SavedPlace? {
        try? modelContext.fetch(
            FetchDescriptor<SavedPlace>(
                predicate: #Predicate { $0.id == placeId && $0.deletedAt == nil }
            )
        ).first
    }

    private func openMaps(for place: SavedPlace, directions: Bool) {
        let coordinate = "\(place.latitude),\(place.longitude)"
        let encodedName = place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? place.name
        let urlString: String
        if directions {
            urlString = "http://maps.apple.com/?daddr=\(coordinate)&q=\(encodedName)"
        } else {
            urlString = "http://maps.apple.com/?ll=\(coordinate)&q=\(encodedName)"
        }

        if let url = URL(string: urlString) {
            openURL(url)
        }
    }
}

private struct SavedPlaceDetailMapCard: View {
    let place: SavedPlace

    @State private var region: MKCoordinateRegion
    @State private var position: MapCameraPosition

    init(place: SavedPlace) {
        self.place = place
        let center = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        let initialRegion = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        _region = State(
            initialValue: initialRegion
        )
        _position = State(initialValue: .region(initialRegion))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Map")
                .font(.headline)

            Map(position: $position, interactionModes: .all) {
                Marker("Selected place", coordinate: annotation.coordinate)
                    .tint(.teal)
            }
            .onMapCameraChange(frequency: .continuous) { context in
                region = context.region
            }
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(alignment: .topLeading) {
                Text("Selected place")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var annotation: SavedPlaceMapAnnotation {
        SavedPlaceMapAnnotation(
            coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        )
    }
}

private struct SavedPlaceMapAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

private struct SavedPlaceDetailRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(title == "Coordinates" ? .body.monospacedDigit() : .body)
                    .foregroundStyle(.primary)
            }
        }
    }
}
