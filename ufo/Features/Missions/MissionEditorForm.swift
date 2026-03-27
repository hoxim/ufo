import SwiftUI
import PhotosUI

struct MissionEditorForm: View {
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
                        title: "Właściciel",
                        value: selectedOwnerTitle,
                        isPlaceholder: ownerId == nil
                    ) {
                        Button("Nieprzypisane") { ownerId = nil }
                        ForEach(availableOwners) { owner in
                            Button(owner.effectiveDisplayName ?? owner.email) { ownerId = owner.id }
                        }
                    }
                    SelectionMenuRow(
                        title: "Miejsce",
                        value: selectedPlaceTitle,
                        isPlaceholder: savedPlaceId == nil
                    ) {
                        Button("Brak miejsca") { savedPlaceId = nil }
                        ForEach(availablePlaces) { place in
                            Button(place.name) { savedPlaceId = place.id }
                        }
                        Divider()
                        Button("Dodaj nowe miejsce") { isPresentingAddPlace = true }
                    }
                    SelectionMenuRow(
                        title: "Priorytet",
                        value: priority.localizedLabel
                    ) {
                        ForEach(MissionPriority.allCases) { value in
                            Button(value.localizedLabel) { priority = value }
                        }
                    }
                    Toggle("Powtarzalna", isOn: $isRecurring)
                    Toggle("Termin", isOn: $dueDateEnabled)
                    if dueDateEnabled {
                        DatePicker("Data", selection: $dueDate)
                    }
                }
                Section("Powiązane") {
                    SelectionMenuRow(
                        title: "Lista",
                        value: selectedListTitle,
                        isPlaceholder: relatedListId == nil
                    ) {
                        Button(String(localized: "common.none")) { relatedListId = nil }
                        ForEach(availableLists) { list in
                            Button(list.name) { relatedListId = list.id }
                        }
                        Divider()
                        Button("Dodaj nową listę") { isPresentingAddList = true }
                    }
                    SelectionMenuRow(
                        title: "Notatka",
                        value: selectedNoteTitle,
                        isPlaceholder: relatedNoteId == nil
                    ) {
                        Button(String(localized: "common.none")) { relatedNoteId = nil }
                        ForEach(availableNotes) { note in
                            Button(note.title) { relatedNoteId = note.id }
                        }
                        Divider()
                        Button("Dodaj nową notatkę") { isPresentingAddNote = true }
                    }
                    SelectionMenuRow(
                        title: "Incydent",
                        value: selectedIncidentTitle,
                        isPlaceholder: relatedIncidentId == nil
                    ) {
                        Button(String(localized: "common.none")) { relatedIncidentId = nil }
                        ForEach(availableIncidents) { incident in
                            Button(incident.title) { relatedIncidentId = incident.id }
                        }
                        Divider()
                        Button("Dodaj nowy incydent") { isPresentingAddIncident = true }
                    }
                }
                Section {
                    DisclosureGroup("Styl", isExpanded: $showStylePicker) {
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
        return trimmedTitle.isEmpty ? "mission draft" : trimmedTitle
    }

    private var selectedOwnerTitle: String {
        availableOwners.first(where: { $0.id == ownerId })?.effectiveDisplayName
            ?? availableOwners.first(where: { $0.id == ownerId })?.email
            ?? "Nieprzypisane"
    }

    private var selectedPlaceTitle: String {
        availablePlaces.first(where: { $0.id == savedPlaceId })?.name ?? "Brak miejsca"
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
