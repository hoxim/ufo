import SwiftUI
import PhotosUI

struct EditMissionView: View {
    @Environment(\.dismiss) private var dismiss

    let store: MissionStore
    let mission: Mission
    let userId: UUID?

    @State private var title: String
    @State private var description: String
    @State private var difficulty: Int
    @State private var iconName: String
    @State private var iconColorHex: String
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var isSaving = false

    init(store: MissionStore, mission: Mission, userId: UUID?) {
        self.store = store
        self.mission = mission
        self.userId = userId
        _title = State(initialValue: mission.title)
        _description = State(initialValue: mission.missionDescription)
        _difficulty = State(initialValue: mission.difficulty)
        _iconName = State(initialValue: mission.iconName ?? "target")
        _iconColorHex = State(initialValue: mission.iconColorHex ?? "#F59E0B")
        _imageData = State(initialValue: mission.imageData)
    }

    var body: some View {
        MissionEditorForm(
            title: $title,
            description: $description,
            difficulty: $difficulty,
            iconName: $iconName,
            iconColorHex: $iconColorHex,
            selectedPhotoItem: $selectedPhotoItem,
            imageData: $imageData,
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

        await store.updateMission(
            mission,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description,
            difficulty: difficulty,
            iconName: iconName.isEmpty ? nil : iconName,
            iconColorHex: iconColorHex,
            imageData: imageData,
            userId: userId
        )
        dismiss()
    }
}

struct AddMissionView: View {
    @Environment(\.dismiss) private var dismiss

    let store: MissionStore
    let userId: UUID?

    @State private var title = ""
    @State private var description = ""
    @State private var difficulty = 1
    @State private var iconName = "target"
    @State private var iconColorHex = "#F59E0B"
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var isSaving = false

    var body: some View {
        MissionEditorForm(
            title: $title,
            description: $description,
            difficulty: $difficulty,
            iconName: $iconName,
            iconColorHex: $iconColorHex,
            selectedPhotoItem: $selectedPhotoItem,
            imageData: $imageData,
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

        await store.addMission(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description,
            difficulty: difficulty,
            iconName: iconName.isEmpty ? nil : iconName,
            iconColorHex: iconColorHex,
            imageData: imageData,
            userId: userId
        )
        dismiss()
    }
}

private struct MissionEditorForm: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var title: String
    @Binding var description: String
    @Binding var difficulty: Int
    @Binding var iconName: String
    @Binding var iconColorHex: String
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var imageData: Data?
    @State private var showStylePicker = false

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
