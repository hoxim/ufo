#if os(iOS)

import SwiftUI
import SwiftData
import PhotosUI

struct PhoneEditIncidentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo

    let store: IncidentStore
    let incident: Incident
    let userId: UUID?
    let availableMissions: [Mission]
    let availableLists: [SharedList]
    let availablePlaces: [SavedPlace]

    @State private var title: String
    @State private var details: String
    @State private var date: Date
    @State private var severity: IncidentSeverity
    @State private var status: IncidentStatus
    @State private var assigneeId: UUID?
    @State private var costText: String
    @State private var iconName: String
    @State private var iconColorHex: String
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var relatedMissionId: UUID?
    @State private var relatedListId: UUID?
    @State private var relatedPlaceId: UUID?
    @State private var isSaving = false
    @State private var showStylePicker = false
    @State private var isPresentingAddPlace = false
    @State private var isPresentingAddList = false
    @State private var isPresentingAddMission = false
    @FocusState private var isTitleFocused: Bool

    init(
        store: IncidentStore,
        incident: Incident,
        userId: UUID?,
        availableMissions: [Mission] = [],
        availableLists: [SharedList] = [],
        availablePlaces: [SavedPlace] = [],
        initialRelatedMissionId: UUID? = nil,
        initialRelatedListId: UUID? = nil,
        initialRelatedPlaceId: UUID? = nil
    ) {
        self.store = store
        self.incident = incident
        self.userId = userId
        self.availableMissions = availableMissions
        self.availableLists = availableLists
        self.availablePlaces = availablePlaces
        _title = State(initialValue: incident.title)
        _details = State(initialValue: incident.incidentDescription ?? "")
        _date = State(initialValue: incident.occurrenceDate)
        _severity = State(initialValue: incident.severity)
        _status = State(initialValue: incident.status)
        _assigneeId = State(initialValue: incident.assigneeId)
        _costText = State(initialValue: incident.cost.map { String($0) } ?? "")
        _iconName = State(initialValue: incident.iconName ?? "bolt.horizontal")
        _iconColorHex = State(initialValue: incident.iconColorHex ?? "#F59E0B")
        _imageData = State(initialValue: incident.imageData)
        _relatedMissionId = State(initialValue: initialRelatedMissionId)
        _relatedListId = State(initialValue: initialRelatedListId)
        _relatedPlaceId = State(initialValue: initialRelatedPlaceId)
    }

    var body: some View {
        AdaptiveFormContent {
            Form {
                TextField("incidents.editor.field.title", text: $title)
                    .prominentFormTextInput()
                    .focused($isTitleFocused)
                TextField("incidents.editor.field.description", text: $details)
                    .prominentFormTextInput()
                DatePicker("incidents.editor.field.date", selection: $date)
                SelectionMenuRow(title: String(localized: "incidents.editor.field.severity"), value: severity.localizedLabel) {
                    ForEach(IncidentSeverity.allCases) { value in
                        Button(value.localizedLabel) { severity = value }
                    }
                }
                SelectionMenuRow(title: String(localized: "incidents.editor.field.status"), value: status.localizedLabel) {
                    ForEach(IncidentStatus.allCases) { value in
                        Button(value.localizedLabel) { status = value }
                    }
                }
                SelectionMenuRow(title: String(localized: "incidents.editor.field.assignee"), value: selectedAssigneeTitle, isPlaceholder: assigneeId == nil) {
                    Button(String(localized: "incidents.editor.option.unassigned")) { assigneeId = nil }
                    if let currentUser = userId {
                        Button(currentUser.uuidString.prefix(8).description) { assigneeId = currentUser }
                    }
                }
                TextField("incidents.editor.field.cost", text: $costText)
                    .prominentFormTextInput()
                    .decimalPadKeyboardIfSupported()
                Section("incidents.editor.section.related") {
                    SelectionMenuRow(title: String(localized: "incidents.editor.field.mission"), value: selectedMissionTitle, isPlaceholder: relatedMissionId == nil) {
                        Button(String(localized: "common.none")) { relatedMissionId = nil }
                        ForEach(resolvedAvailableMissions) { mission in
                            Button(mission.title) { relatedMissionId = mission.id }
                        }
                        Divider()
                        Button(String(localized: "incidents.editor.action.addMission")) { isPresentingAddMission = true }
                    }
                    SelectionMenuRow(title: String(localized: "incidents.editor.field.list"), value: selectedListTitle, isPlaceholder: relatedListId == nil) {
                        Button(String(localized: "common.none")) { relatedListId = nil }
                        ForEach(resolvedAvailableLists) { list in
                            Button(list.name) { relatedListId = list.id }
                        }
                        Divider()
                        Button(String(localized: "incidents.editor.action.addList")) { isPresentingAddList = true }
                    }
                    SelectionMenuRow(title: String(localized: "incidents.editor.field.place"), value: selectedPlaceTitle, isPlaceholder: relatedPlaceId == nil) {
                        Button(String(localized: "common.none")) { relatedPlaceId = nil }
                        ForEach(resolvedAvailablePlaces) { place in
                            Button(place.name) { relatedPlaceId = place.id }
                        }
                        Divider()
                        Button(String(localized: "incidents.editor.action.addPlace")) { isPresentingAddPlace = true }
                    }
                }
                DisclosureGroup("incidents.editor.section.style", isExpanded: $showStylePicker) {
                    OperationStylePicker(iconName: $iconName, colorHex: $iconColorHex)
                }
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("common.selectImage", systemImage: "photo")
                }
                if imageData != nil {
                    Text("common.imageSelected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("incidents.editor.title.edit")
            .modalInlineTitleDisplayMode()
            .toolbar {
                ModalCloseToolbarItem {
                    dismiss()
                }
                ModalConfirmToolbarItem(
                    isDisabled: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving,
                    isProcessing: isSaving,
                    action: {
                        Task { await save() }
                    }
                )
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                guard let newValue else { return }
                Task {
                    imageData = try? await newValue.loadTransferable(type: Data.self)
                }
            }
            .sheet(isPresented: $isPresentingAddPlace) {
                QuickAddPlaceSheet(originLabel: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? String(localized: "incidents.editor.originDraft") : title) { place in
                    relatedPlaceId = place.id
                }
            }
            .sheet(isPresented: $isPresentingAddMission) {
                QuickCreateMissionSheet(
                    initialSavedPlaceId: relatedPlaceId,
                    initialRelatedListId: relatedListId,
                    originLabel: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? String(localized: "incidents.editor.originDraft") : title
                ) { missionId in
                    relatedMissionId = missionId
                }
            }
            .sheet(isPresented: $isPresentingAddList) {
                QuickCreateLinkedListSheet(
                    initialSavedPlaceId: relatedPlaceId,
                    originLabel: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? String(localized: "incidents.editor.originDraft") : title
                ) { listId in
                    relatedListId = listId
                }
            }
            .onAppear {
                if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    isTitleFocused = true
                }
            }
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }

        await store.updateIncident(
            incident,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: details.isEmpty ? nil : details,
            severity: severity,
            status: status,
            assigneeId: assigneeId,
            cost: Double(costText.replacingOccurrences(of: ",", with: ".")),
            occurrenceDate: date,
            iconName: iconName.isEmpty ? nil : iconName,
            iconColorHex: iconColorHex,
            imageData: imageData,
            relatedMissionId: relatedMissionId,
            relatedListId: relatedListId,
            relatedPlaceId: relatedPlaceId,
            managedRelatedIds: managedRelatedIds,
            userId: userId
        )
        dismiss()
    }

    private var resolvedAvailableMissions: [Mission] {
        guard let spaceId = spaceRepo.selectedSpace?.id else { return availableMissions }
        return (try? modelContext.fetch(
            FetchDescriptor<Mission>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )) ?? availableMissions
    }

    private var resolvedAvailableLists: [SharedList] {
        guard let spaceId = spaceRepo.selectedSpace?.id else { return availableLists }
        return (try? modelContext.fetch(
            FetchDescriptor<SharedList>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )) ?? availableLists
    }

    private var resolvedAvailablePlaces: [SavedPlace] {
        guard let spaceId = spaceRepo.selectedSpace?.id else { return availablePlaces }
        return (try? modelContext.fetch(
            FetchDescriptor<SavedPlace>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.name, order: .forward)]
            )
        )) ?? availablePlaces
    }

    private var selectedMissionTitle: String {
        resolvedAvailableMissions.first(where: { $0.id == relatedMissionId })?.title ?? String(localized: "common.none")
    }

    private var selectedListTitle: String {
        resolvedAvailableLists.first(where: { $0.id == relatedListId })?.name ?? String(localized: "common.none")
    }

    private var selectedPlaceTitle: String {
        resolvedAvailablePlaces.first(where: { $0.id == relatedPlaceId })?.name ?? String(localized: "common.none")
    }

    private var selectedAssigneeTitle: String {
        assigneeId.map { String($0.uuidString.prefix(8)) } ?? String(localized: "incidents.editor.option.unassigned")
    }
}

private extension PhoneEditIncidentView {
    var managedRelatedIds: [UUID] {
        Array(Set(resolvedAvailableMissions.map(\.id) + resolvedAvailableLists.map(\.id) + resolvedAvailablePlaces.map(\.id)))
    }
}

#endif
