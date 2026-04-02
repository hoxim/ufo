#if os(iOS)

import SwiftUI
import PhotosUI
import SwiftData

struct PhoneEditMissionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNotificationStore.self) private var notificationStore
    @Environment(SpaceRepository.self) private var spaceRepo

    let store: MissionStore
    let mission: Mission
    let userId: UUID?
    let availableOwners: [UserProfile]
    let availablePlaces: [SavedPlace]
    let availableLists: [SharedList]
    let availableNotes: [Note]
    let availableIncidents: [Incident]

    @State private var title: String
    @State private var description: String
    @State private var difficulty: Int
    @State private var ownerId: UUID?
    @State private var dueDateEnabled: Bool
    @State private var dueDate: Date
    @State private var savedPlaceId: UUID?
    @State private var relatedListId: UUID?
    @State private var relatedNoteId: UUID?
    @State private var relatedIncidentId: UUID?
    @State private var priority: MissionPriority
    @State private var isRecurring: Bool
    @State private var iconName: String
    @State private var iconColorHex: String
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var isSaving = false

    init(
        store: MissionStore,
        mission: Mission,
        userId: UUID?,
        availableOwners: [UserProfile] = [],
        availablePlaces: [SavedPlace] = [],
        availableLists: [SharedList] = [],
        availableNotes: [Note] = [],
        availableIncidents: [Incident] = [],
        initialRelatedListId: UUID? = nil,
        initialRelatedNoteId: UUID? = nil,
        initialRelatedIncidentId: UUID? = nil
    ) {
        self.store = store
        self.mission = mission
        self.userId = userId
        self.availableOwners = availableOwners
        self.availablePlaces = availablePlaces
        self.availableLists = availableLists
        self.availableNotes = availableNotes
        self.availableIncidents = availableIncidents
        _title = State(initialValue: mission.title)
        _description = State(initialValue: mission.missionDescription)
        _difficulty = State(initialValue: mission.difficulty)
        _ownerId = State(initialValue: mission.ownerId)
        _dueDateEnabled = State(initialValue: mission.dueDate != nil)
        _dueDate = State(initialValue: mission.dueDate ?? .now)
        _savedPlaceId = State(initialValue: mission.savedPlaceId)
        _relatedListId = State(initialValue: initialRelatedListId)
        _relatedNoteId = State(initialValue: initialRelatedNoteId)
        _relatedIncidentId = State(initialValue: initialRelatedIncidentId)
        _priority = State(initialValue: MissionPriority(rawValue: mission.resolvedPriority) ?? .medium)
        _isRecurring = State(initialValue: mission.isRecurringValue)
        _iconName = State(initialValue: mission.iconName ?? "target")
        _iconColorHex = State(initialValue: mission.iconColorHex ?? "#F59E0B")
        _imageData = State(initialValue: mission.imageData)
    }

    var body: some View {
        PhoneMissionEditorForm(
            title: $title,
            description: $description,
            difficulty: $difficulty,
            ownerId: $ownerId,
            dueDateEnabled: $dueDateEnabled,
            dueDate: $dueDate,
            savedPlaceId: $savedPlaceId,
            relatedListId: $relatedListId,
            relatedNoteId: $relatedNoteId,
            relatedIncidentId: $relatedIncidentId,
            priority: $priority,
            isRecurring: $isRecurring,
            iconName: $iconName,
            iconColorHex: $iconColorHex,
            selectedPhotoItem: $selectedPhotoItem,
            imageData: $imageData,
            availablePlaces: resolvedAvailablePlaces,
            availableOwners: availableOwners,
            availableLists: resolvedAvailableLists,
            availableNotes: resolvedAvailableNotes,
            availableIncidents: resolvedAvailableIncidents,
            isSaving: isSaving,
            navigationTitle: "missions.editor.title.edit",
            onSave: {
                Task { await save() }
            }
        )
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue else { return }
            Task {
                imageData = try? await newValue.loadTransferable(type: Data.self)
            }
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let didSave = await store.updateMission(
            mission,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description,
            difficulty: difficulty,
            ownerId: ownerId,
            dueDate: dueDateEnabled ? dueDate : nil,
            savedPlaceId: savedPlaceId,
            savedPlaceName: resolvedAvailablePlaces.first(where: { $0.id == savedPlaceId })?.name,
            priority: priority.rawValue,
            isRecurring: isRecurring,
            iconName: iconName.isEmpty ? nil : iconName,
            iconColorHex: iconColorHex,
            imageData: imageData,
            relatedListId: relatedListId,
            relatedNoteId: relatedNoteId,
            relatedIncidentId: relatedIncidentId,
            managedRelatedIds: managedRelatedIds,
            userId: userId
        )
        guard didSave else { return }

        notificationStore.addNotification(
            title: "Mission zaktualizowana",
            body: "Zmiany w mission \(title.trimmingCharacters(in: .whitespacesAndNewlines)) zostały zapisane.",
            category: .info,
            priority: .normal,
            source: "mission-edit",
            toast: AppToast(title: "Mission zaktualizowana", message: nil, style: .success)
        )
        dismiss()
    }

    private var resolvedAvailablePlaces: [SavedPlace] {
        PhoneMissionEditorSupport.resolvedPlaces(
            modelContext: modelContext,
            spaceId: spaceRepo.selectedSpace?.id,
            fallback: availablePlaces
        )
    }

    private var resolvedAvailableLists: [SharedList] {
        PhoneMissionEditorSupport.resolvedLists(
            modelContext: modelContext,
            spaceId: spaceRepo.selectedSpace?.id,
            fallback: availableLists
        )
    }

    private var resolvedAvailableNotes: [Note] {
        PhoneMissionEditorSupport.resolvedNotes(
            modelContext: modelContext,
            spaceId: spaceRepo.selectedSpace?.id,
            fallback: availableNotes
        )
    }

    private var resolvedAvailableIncidents: [Incident] {
        PhoneMissionEditorSupport.resolvedIncidents(
            modelContext: modelContext,
            spaceId: spaceRepo.selectedSpace?.id,
            fallback: availableIncidents
        )
    }
}

struct PhoneAddMissionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNotificationStore.self) private var notificationStore
    @Environment(SpaceRepository.self) private var spaceRepo

    let store: MissionStore
    let userId: UUID?
    let availableOwners: [UserProfile]
    let availablePlaces: [SavedPlace]
    let availableLists: [SharedList]
    let availableNotes: [Note]
    let availableIncidents: [Incident]
    var onCreated: ((UUID) -> Void)? = nil

    @State private var title = ""
    @State private var description = ""
    @State private var difficulty = 1
    @State private var ownerId: UUID?
    @State private var dueDateEnabled = false
    @State private var dueDate = Date()
    @State private var savedPlaceId: UUID?
    @State private var relatedListId: UUID?
    @State private var relatedNoteId: UUID?
    @State private var relatedIncidentId: UUID?
    @State private var priority: MissionPriority = .medium
    @State private var isRecurring = false
    @State private var iconName = "target"
    @State private var iconColorHex = "#F59E0B"
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var isSaving = false

    init(
        store: MissionStore,
        userId: UUID?,
        availableOwners: [UserProfile] = [],
        availablePlaces: [SavedPlace] = [],
        availableLists: [SharedList] = [],
        availableNotes: [Note] = [],
        availableIncidents: [Incident] = [],
        initialSavedPlaceId: UUID? = nil,
        initialRelatedListId: UUID? = nil,
        initialRelatedNoteId: UUID? = nil,
        initialRelatedIncidentId: UUID? = nil,
        onCreated: ((UUID) -> Void)? = nil
    ) {
        self.store = store
        self.userId = userId
        self.availableOwners = availableOwners
        self.availablePlaces = availablePlaces
        self.availableLists = availableLists
        self.availableNotes = availableNotes
        self.availableIncidents = availableIncidents
        self.onCreated = onCreated
        _savedPlaceId = State(initialValue: initialSavedPlaceId)
        _relatedListId = State(initialValue: initialRelatedListId)
        _relatedNoteId = State(initialValue: initialRelatedNoteId)
        _relatedIncidentId = State(initialValue: initialRelatedIncidentId)
    }

    var body: some View {
        PhoneMissionEditorForm(
            title: $title,
            description: $description,
            difficulty: $difficulty,
            ownerId: $ownerId,
            dueDateEnabled: $dueDateEnabled,
            dueDate: $dueDate,
            savedPlaceId: $savedPlaceId,
            relatedListId: $relatedListId,
            relatedNoteId: $relatedNoteId,
            relatedIncidentId: $relatedIncidentId,
            priority: $priority,
            isRecurring: $isRecurring,
            iconName: $iconName,
            iconColorHex: $iconColorHex,
            selectedPhotoItem: $selectedPhotoItem,
            imageData: $imageData,
            availablePlaces: resolvedAvailablePlaces,
            availableOwners: availableOwners,
            availableLists: resolvedAvailableLists,
            availableNotes: resolvedAvailableNotes,
            availableIncidents: resolvedAvailableIncidents,
            isSaving: isSaving,
            navigationTitle: "missions.editor.title.new",
            onSave: {
                Task { await save() }
            }
        )
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue else { return }
            Task {
                imageData = try? await newValue.loadTransferable(type: Data.self)
            }
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        let createdMission = await store.addMission(
            title: trimmedTitle,
            description: description,
            difficulty: difficulty,
            ownerId: ownerId,
            dueDate: dueDateEnabled ? dueDate : nil,
            savedPlaceId: savedPlaceId,
            savedPlaceName: resolvedAvailablePlaces.first(where: { $0.id == savedPlaceId })?.name,
            priority: priority.rawValue,
            isRecurring: isRecurring,
            iconName: iconName.isEmpty ? nil : iconName,
            iconColorHex: iconColorHex,
            imageData: imageData,
            relatedListId: relatedListId,
            relatedNoteId: relatedNoteId,
            relatedIncidentId: relatedIncidentId,
            managedRelatedIds: managedRelatedIds,
            userId: userId
        )
        guard let createdMission else { return }

        notificationStore.addNotification(
            title: "Mission dodana",
            body: "Mission \(trimmedTitle) została dodana do Twojej przestrzeni.",
            category: .info,
            priority: .normal,
            source: "mission-create",
            toast: AppToast(title: "Mission dodana", message: trimmedTitle, style: .success)
        )

        if dueDateEnabled {
            let reminderDate = dueDate.addingTimeInterval(-3600)
            if reminderDate > .now {
                notificationStore.addNotification(
                    title: "Przypomnienie o mission",
                    body: "Za godzinę startuje lub kończy się: \(trimmedTitle).",
                    category: .alert,
                    priority: .important,
                    scheduledAt: reminderDate,
                    source: "mission-reminder"
                )
            }
        }
        onCreated?(createdMission.id)
        dismiss()
    }

    private var resolvedAvailablePlaces: [SavedPlace] {
        PhoneMissionEditorSupport.resolvedPlaces(
            modelContext: modelContext,
            spaceId: spaceRepo.selectedSpace?.id,
            fallback: availablePlaces
        )
    }

    private var resolvedAvailableLists: [SharedList] {
        PhoneMissionEditorSupport.resolvedLists(
            modelContext: modelContext,
            spaceId: spaceRepo.selectedSpace?.id,
            fallback: availableLists
        )
    }

    private var resolvedAvailableNotes: [Note] {
        PhoneMissionEditorSupport.resolvedNotes(
            modelContext: modelContext,
            spaceId: spaceRepo.selectedSpace?.id,
            fallback: availableNotes
        )
    }

    private var resolvedAvailableIncidents: [Incident] {
        PhoneMissionEditorSupport.resolvedIncidents(
            modelContext: modelContext,
            spaceId: spaceRepo.selectedSpace?.id,
            fallback: availableIncidents
        )
    }
}

private extension PhoneEditMissionView {
    var managedRelatedIds: [UUID] {
        PhoneMissionEditorSupport.managedRelatedIds(
            lists: resolvedAvailableLists,
            notes: resolvedAvailableNotes,
            incidents: resolvedAvailableIncidents
        )
    }
}

private extension PhoneAddMissionView {
    var managedRelatedIds: [UUID] {
        PhoneMissionEditorSupport.managedRelatedIds(
            lists: resolvedAvailableLists,
            notes: resolvedAvailableNotes,
            incidents: resolvedAvailableIncidents
        )
    }
}

#endif
