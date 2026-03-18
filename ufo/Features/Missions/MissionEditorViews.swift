import SwiftUI
import PhotosUI

struct EditMissionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppNotificationStore.self) private var notificationStore

    let store: MissionStore
    let mission: Mission
    let userId: UUID?
    let availableOwners: [UserProfile]
    let availablePlaces: [SavedPlace]

    @State private var title: String
    @State private var description: String
    @State private var difficulty: Int
    @State private var ownerId: UUID?
    @State private var dueDateEnabled: Bool
    @State private var dueDate: Date
    @State private var savedPlaceId: UUID?
    @State private var priority: MissionPriority
    @State private var isRecurring: Bool
    @State private var iconName: String
    @State private var iconColorHex: String
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var isSaving = false

    init(store: MissionStore, mission: Mission, userId: UUID?, availableOwners: [UserProfile] = [], availablePlaces: [SavedPlace] = []) {
        self.store = store
        self.mission = mission
        self.userId = userId
        self.availableOwners = availableOwners
        self.availablePlaces = availablePlaces
        _title = State(initialValue: mission.title)
        _description = State(initialValue: mission.missionDescription)
        _difficulty = State(initialValue: mission.difficulty)
        _ownerId = State(initialValue: mission.ownerId)
        _dueDateEnabled = State(initialValue: mission.dueDate != nil)
        _dueDate = State(initialValue: mission.dueDate ?? .now)
        _savedPlaceId = State(initialValue: mission.savedPlaceId)
        _priority = State(initialValue: MissionPriority(rawValue: mission.resolvedPriority) ?? .medium)
        _isRecurring = State(initialValue: mission.isRecurringValue)
        _iconName = State(initialValue: mission.iconName ?? "target")
        _iconColorHex = State(initialValue: mission.iconColorHex ?? "#F59E0B")
        _imageData = State(initialValue: mission.imageData)
    }

    var body: some View {
        MissionEditorForm(
            title: $title,
            description: $description,
            difficulty: $difficulty,
            ownerId: $ownerId,
            dueDateEnabled: $dueDateEnabled,
            dueDate: $dueDate,
            savedPlaceId: $savedPlaceId,
            priority: $priority,
            isRecurring: $isRecurring,
            iconName: $iconName,
            iconColorHex: $iconColorHex,
            selectedPhotoItem: $selectedPhotoItem,
            imageData: $imageData,
            availablePlaces: availablePlaces,
            availableOwners: availableOwners,
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
            savedPlaceName: availablePlaces.first(where: { $0.id == savedPlaceId })?.name,
            priority: priority.rawValue,
            isRecurring: isRecurring,
            iconName: iconName.isEmpty ? nil : iconName,
            iconColorHex: iconColorHex,
            imageData: imageData,
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
}

struct AddMissionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppNotificationStore.self) private var notificationStore

    let store: MissionStore
    let userId: UUID?
    let availableOwners: [UserProfile]
    let availablePlaces: [SavedPlace]

    @State private var title = ""
    @State private var description = ""
    @State private var difficulty = 1
    @State private var ownerId: UUID?
    @State private var dueDateEnabled = false
    @State private var dueDate = Date()
    @State private var savedPlaceId: UUID?
    @State private var priority: MissionPriority = .medium
    @State private var isRecurring = false
    @State private var iconName = "target"
    @State private var iconColorHex = "#F59E0B"
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var isSaving = false

    init(store: MissionStore, userId: UUID?, availableOwners: [UserProfile] = [], availablePlaces: [SavedPlace] = []) {
        self.store = store
        self.userId = userId
        self.availableOwners = availableOwners
        self.availablePlaces = availablePlaces
    }

    var body: some View {
        MissionEditorForm(
            title: $title,
            description: $description,
            difficulty: $difficulty,
            ownerId: $ownerId,
            dueDateEnabled: $dueDateEnabled,
            dueDate: $dueDate,
            savedPlaceId: $savedPlaceId,
            priority: $priority,
            isRecurring: $isRecurring,
            iconName: $iconName,
            iconColorHex: $iconColorHex,
            selectedPhotoItem: $selectedPhotoItem,
            imageData: $imageData,
            availablePlaces: availablePlaces,
            availableOwners: availableOwners,
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
            savedPlaceName: availablePlaces.first(where: { $0.id == savedPlaceId })?.name,
            priority: priority.rawValue,
            isRecurring: isRecurring,
            iconName: iconName.isEmpty ? nil : iconName,
            iconColorHex: iconColorHex,
            imageData: imageData,
            userId: userId
        )
        guard createdMission != nil else { return }

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
        dismiss()
    }
}

private struct MissionEditorForm: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var title: String
    @Binding var description: String
    @Binding var difficulty: Int
    @Binding var ownerId: UUID?
    @Binding var dueDateEnabled: Bool
    @Binding var dueDate: Date
    @Binding var savedPlaceId: UUID?
    @Binding var priority: MissionPriority
    @Binding var isRecurring: Bool
    @Binding var iconName: String
    @Binding var iconColorHex: String
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var imageData: Data?
    @State private var showStylePicker = false

    let availablePlaces: [SavedPlace]
    let availableOwners: [UserProfile]
    let isSaving: Bool
    let navigationTitle: LocalizedStringKey
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("missions.editor.field.title", text: $title)
                        .submitLabel(.done)
                    TextField("missions.editor.field.description", text: $description, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section {
                    Stepper(
                        "\(String(localized: "missions.editor.field.difficulty")): \(difficulty)",
                        value: $difficulty,
                        in: 1...5
                    )
                    Picker("Owner", selection: $ownerId) {
                        Text("Unassigned").tag(UUID?.none)
                        ForEach(availableOwners) { owner in
                            Text(owner.effectiveDisplayName ?? owner.email).tag(UUID?.some(owner.id))
                        }
                    }
                    Picker("Place", selection: $savedPlaceId) {
                        Text("No place").tag(UUID?.none)
                        ForEach(availablePlaces) { place in
                            Text(place.name).tag(UUID?.some(place.id))
                        }
                    }
                    Picker("Priority", selection: $priority) {
                        ForEach(MissionPriority.allCases) { value in
                            Text(value.localizedLabel).tag(value)
                        }
                    }
                    Toggle("Recurring", isOn: $isRecurring)
                    Toggle("Due date", isOn: $dueDateEnabled)
                    if dueDateEnabled {
                        DatePicker("Due", selection: $dueDate)
                    }
                }
                Section {
                    DisclosureGroup("Style", isExpanded: $showStylePicker) {
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: onSave) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }
}
