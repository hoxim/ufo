#if os(iOS)

import SwiftUI
import PhotosUI

struct PadMissionEditorForm: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPresentingAddPlace = false
    @State private var isPresentingAddList = false
    @State private var isPresentingAddNote = false
    @State private var isPresentingAddIncident = false

    @Binding var title: String
    @Binding var description: String
    @Binding var difficulty: Int
    @Binding var ownerId: UUID?
    @Binding var dueDateEnabled: Bool
    @Binding var dueDate: Date
    @Binding var savedPlaceId: UUID?
    @Binding var relatedListId: UUID?
    @Binding var relatedNoteId: UUID?
    @Binding var relatedIncidentId: UUID?
    @Binding var priority: MissionPriority
    @Binding var isRecurring: Bool
    @Binding var iconName: String
    @Binding var iconColorHex: String
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var imageData: Data?
    @State private var showStylePicker = false
    @FocusState private var isTitleFocused: Bool

    let availablePlaces: [SavedPlace]
    let availableOwners: [UserProfile]
    let availableLists: [SharedList]
    let availableNotes: [Note]
    let availableIncidents: [Incident]
    let isSaving: Bool
    let navigationTitle: LocalizedStringKey
    let onSave: () -> Void

    var body: some View {
        AdaptiveFormContent {
            Form {
                Section {
                    TextField("missions.editor.field.title", text: $title)
                        .prominentFormTextInput()
                        .focused($isTitleFocused)
                        .submitLabel(.done)
                    TextField("missions.editor.field.description", text: $description, axis: .vertical)
                        .lineLimit(2...5)
                        .prominentFormTextInput()
                }
                Section {
                    Stepper(
                        "\(String(localized: "missions.editor.field.difficulty")): \(difficulty)",
                        value: $difficulty,
                        in: 1...5
                    )
                    SelectionMenuRow(
                        title: String(localized: "missions.editor.field.owner"),
                        value: selectedOwnerTitle,
                        isPlaceholder: ownerId == nil
                    ) {
                        Button(String(localized: "missions.editor.option.unassigned")) { ownerId = nil }
                        ForEach(availableOwners) { owner in
                            Button(owner.effectiveDisplayName ?? owner.email) { ownerId = owner.id }
                        }
                    }
                    SelectionMenuRow(
                        title: String(localized: "missions.editor.field.place"),
                        value: selectedPlaceTitle,
                        isPlaceholder: savedPlaceId == nil
                    ) {
                        Button(String(localized: "missions.editor.option.noPlace")) { savedPlaceId = nil }
                        ForEach(availablePlaces) { place in
                            Button(place.name) { savedPlaceId = place.id }
                        }
                        Divider()
                        Button(String(localized: "missions.editor.action.addPlace")) { isPresentingAddPlace = true }
                    }
                    SelectionMenuRow(
                        title: String(localized: "missions.editor.field.priority"),
                        value: priority.localizedLabel
                    ) {
                        ForEach(MissionPriority.allCases) { value in
                            Button(value.localizedLabel) { priority = value }
                        }
                    }
                    Toggle("missions.editor.field.recurring", isOn: $isRecurring)
                    Toggle("missions.editor.field.dueDateToggle", isOn: $dueDateEnabled)
                    if dueDateEnabled {
                        DatePicker("missions.editor.field.date", selection: $dueDate)
                    }
                }
                Section("missions.editor.section.related") {
                    SelectionMenuRow(
                        title: String(localized: "missions.editor.field.list"),
                        value: selectedListTitle,
                        isPlaceholder: relatedListId == nil
                    ) {
                        Button(String(localized: "common.none")) { relatedListId = nil }
                        ForEach(availableLists) { list in
                            Button(list.name) { relatedListId = list.id }
                        }
                        Divider()
                        Button(String(localized: "missions.editor.action.addList")) { isPresentingAddList = true }
                    }
                    SelectionMenuRow(
                        title: String(localized: "missions.editor.field.note"),
                        value: selectedNoteTitle,
                        isPlaceholder: relatedNoteId == nil
                    ) {
                        Button(String(localized: "common.none")) { relatedNoteId = nil }
                        ForEach(availableNotes) { note in
                            Button(note.title) { relatedNoteId = note.id }
                        }
                        Divider()
                        Button(String(localized: "missions.editor.action.addNote")) { isPresentingAddNote = true }
                    }
                    SelectionMenuRow(
                        title: String(localized: "missions.editor.field.incident"),
                        value: selectedIncidentTitle,
                        isPlaceholder: relatedIncidentId == nil
                    ) {
                        Button(String(localized: "common.none")) { relatedIncidentId = nil }
                        ForEach(availableIncidents) { incident in
                            Button(incident.title) { relatedIncidentId = incident.id }
                        }
                        Divider()
                        Button(String(localized: "missions.editor.action.addIncident")) { isPresentingAddIncident = true }
                    }
                }
                Section {
                    DisclosureGroup("missions.editor.section.style", isExpanded: $showStylePicker) {
                        OperationStylePicker(iconName: $iconName, colorHex: $iconColorHex)
                    }
                }
                Section {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("common.selectImage", systemImage: "photo")
                    }
                    .buttonStyle(.bordered)
                    if imageData != nil {
                        Text("common.imageSelected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .modalInlineTitleDisplayMode()
            .toolbar {
                ModalCloseToolbarItem {
                    dismiss()
                }
                ModalConfirmToolbarItem(
                    isDisabled: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving,
                    isProcessing: isSaving,
                    action: onSave
                )
            }
            .sheet(isPresented: $isPresentingAddPlace) {
                QuickAddPlaceSheet(originLabel: originLabel) { place in
                    savedPlaceId = place.id
                }
            }
            .sheet(isPresented: $isPresentingAddList) {
                QuickCreateLinkedListSheet(
                    initialSavedPlaceId: savedPlaceId,
                    originLabel: originLabel
                ) { listId in
                    relatedListId = listId
                }
            }
            .sheet(isPresented: $isPresentingAddNote) {
                QuickCreateNoteSheet(
                    prefillLinkedEntityType: .mission,
                    prefillLinkedEntityId: nil,
                    prefillSavedPlaceId: savedPlaceId,
                    prefillSelectedIncidentId: relatedIncidentId,
                    originLabel: originLabel
                ) { noteId in
                    relatedNoteId = noteId
                }
            }
            .sheet(isPresented: $isPresentingAddIncident) {
                QuickCreateIncidentSheet(
                    initialRelatedMissionId: nil,
                    initialRelatedListId: relatedListId,
                    initialRelatedPlaceId: savedPlaceId,
                    originLabel: originLabel
                ) { incidentId in
                    relatedIncidentId = incidentId
                }
            }
            .onAppear {
                if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    isTitleFocused = true
                }
            }
        }
    }

    private var originLabel: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? String(localized: "missions.editor.originDraft") : trimmedTitle
    }

    private var selectedOwnerTitle: String {
        availableOwners.first(where: { $0.id == ownerId })?.effectiveDisplayName
            ?? availableOwners.first(where: { $0.id == ownerId })?.email
            ?? String(localized: "missions.editor.option.unassigned")
    }

    private var selectedPlaceTitle: String {
        availablePlaces.first(where: { $0.id == savedPlaceId })?.name ?? String(localized: "missions.editor.option.noPlace")
    }

    private var selectedListTitle: String {
        availableLists.first(where: { $0.id == relatedListId })?.name ?? String(localized: "common.none")
    }

    private var selectedNoteTitle: String {
        availableNotes.first(where: { $0.id == relatedNoteId })?.title ?? String(localized: "common.none")
    }

    private var selectedIncidentTitle: String {
        availableIncidents.first(where: { $0.id == relatedIncidentId })?.title ?? String(localized: "common.none")
    }
}

private struct PadMissionEditorFormPreviewHost: View {
    @State private var title = "Prepare weekend trip"
    @State private var description = "Pack chargers, documents and snacks."
    @State private var difficulty = 3
    @State private var ownerId: UUID? = PadMissionEditorPreviewData.owner.id
    @State private var dueDateEnabled = true
    @State private var dueDate = Date.now.addingTimeInterval(86_400)
    @State private var savedPlaceId: UUID? = PadMissionEditorPreviewData.place.id
    @State private var relatedListId: UUID? = PadMissionEditorPreviewData.list.id
    @State private var relatedNoteId: UUID? = PadMissionEditorPreviewData.note.id
    @State private var relatedIncidentId: UUID? = PadMissionEditorPreviewData.incident.id
    @State private var priority: MissionPriority = .high
    @State private var isRecurring = false
    @State private var iconName = "flag.fill"
    @State private var iconColorHex = "#F59E0B"
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageData: Data?

    var body: some View {
        PadMissionEditorForm(
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
            availablePlaces: [PadMissionEditorPreviewData.place],
            availableOwners: [PadMissionEditorPreviewData.owner],
            availableLists: [PadMissionEditorPreviewData.list],
            availableNotes: [PadMissionEditorPreviewData.note],
            availableIncidents: [PadMissionEditorPreviewData.incident],
            isSaving: false,
            navigationTitle: "missions.editor.title.new",
            onSave: {}
        )
    }
}

private enum PadMissionEditorPreviewData {
    static let owner = UserProfile(id: UUID(), email: "preview@ufo.app", fullName: "Preview User", role: "admin")
    static let spaceId = UUID()
    static let place = SavedPlace(
        spaceId: spaceId,
        name: "Home",
        placeDescription: "Main base",
        iconName: "house.fill",
        iconColorHex: "#2563EB",
        address: "Marszalkowska 1, Warszawa",
        latitude: 52.2297,
        longitude: 21.0122,
        createdBy: owner.id
    )
    static let list = SharedList(spaceId: spaceId, name: "Trip checklist", type: SharedListType.shopping.rawValue)
    static let note = Note(spaceId: spaceId, title: "Packing notes", content: "Remember passports.", createdBy: owner.id)
    static let incident = Incident(
        spaceId: spaceId,
        title: "Storm warning",
        incidentDescription: "Watch the weather before departure.",
        occurrenceDate: .now,
        createdBy: owner.id
    )
}

#Preview("Pad Mission Editor Form") {
    NavigationStack {
        PadMissionEditorFormPreviewHost()
    }
}

#endif
