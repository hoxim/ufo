//
//  NoteEditorView.swift
//  ufo
//
//  Created by Marcin Ryzko on 17/03/2026.
//

import SwiftUI
import SwiftData

struct NoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    
    let noteStore: NoteStore
    let note: Note?
    let folders: [NoteFolder]
    let incidents: [Incident]
    let locations: [LocationPing]
    let savedPlaces: [SavedPlace]
    let actorId: UUID?
    
    @State private var title: String
    @State private var content: String
    @State private var selectedFolderId: UUID?
    @State private var attachedLinkURL: String
    @State private var tagsText: String
    @State private var isPinned: Bool
    @State private var linkedEntityType: NoteLinkedEntityType?
    @State private var linkedEntityIdText: String
    @State private var savedPlaceId: UUID?
    @State private var selectedIncidentId: UUID?
    @State private var selectedLocationId: UUID?
    @State private var isSaving = false
    
    init(
        noteStore: NoteStore,
        note: Note? = nil,
        folders: [NoteFolder],
        incidents: [Incident],
        locations: [LocationPing],
        savedPlaces: [SavedPlace] = [],
        actorId: UUID?
    ) {
        self.noteStore = noteStore
        self.note = note
        self.folders = folders
        self.incidents = incidents
        self.locations = locations
        self.savedPlaces = savedPlaces
        self.actorId = actorId
        _title = State(initialValue: note?.title ?? "")
        _content = State(initialValue: note?.content ?? "")
        _selectedFolderId = State(initialValue: note?.folderId)
        _attachedLinkURL = State(initialValue: note?.attachedLinkURL ?? "")
        _tagsText = State(initialValue: note?.resolvedTags.joined(separator: ", ") ?? "")
        _isPinned = State(initialValue: note?.isPinnedValue ?? false)
        _linkedEntityType = State(initialValue: note.flatMap { $0.linkedEntityType }.flatMap(NoteLinkedEntityType.init(rawValue:)))
        _linkedEntityIdText = State(initialValue: note?.linkedEntityId?.uuidString ?? "")
        _savedPlaceId = State(initialValue: note?.savedPlaceId)
        _selectedIncidentId = State(initialValue: note?.relatedIncidentId)
        _selectedLocationId = State(initialValue: Self.locationSelectionId(for: note, locations: locations))
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
                TextField("Tags (comma separated)", text: $tagsText)
                Toggle("Pinned", isOn: $isPinned)
                Picker("Place", selection: $savedPlaceId) {
                    Text("None").tag(UUID?.none)
                    ForEach(savedPlaces) { place in
                        Text(place.name).tag(UUID?.some(place.id))
                    }
                }
                Picker("Linked item type", selection: $linkedEntityType) {
                    Text("None").tag(NoteLinkedEntityType?.none)
                    ForEach(NoteLinkedEntityType.allCases) { type in
                        Text(type.localizedLabel).tag(NoteLinkedEntityType?.some(type))
                    }
                }
                if linkedEntityType != nil {
                    TextField("Linked item ID", text: $linkedEntityIdText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
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
            }
            .navigationTitle(note == nil ? "notes.editor.title.new" : "notes.editor.title.edit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
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
    
    /// Persists note changes and closes sheet when operation succeeds.
    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }
        
        let location = locations.first { $0.id == selectedLocationId }
        let cleanLink = attachedLinkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let linkedEntityId = UUID(uuidString: linkedEntityIdText.trimmingCharacters(in: .whitespacesAndNewlines))
        if let note {
            await noteStore.updateNote(
                note,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                content: content,
                folderId: selectedFolderId,
                attachedLinkURL: cleanLink.isEmpty ? nil : cleanLink,
                tags: tags,
                isPinned: isPinned,
                linkedEntityType: linkedEntityType?.rawValue,
                linkedEntityId: linkedEntityId,
                savedPlaceId: savedPlaceId,
                savedPlaceName: savedPlaces.first(where: { $0.id == savedPlaceId })?.name,
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
                tags: tags,
                isPinned: isPinned,
                linkedEntityType: linkedEntityType?.rawValue,
                linkedEntityId: linkedEntityId,
                savedPlaceId: savedPlaceId,
                savedPlaceName: savedPlaces.first(where: { $0.id == savedPlaceId })?.name,
                relatedIncidentId: selectedIncidentId,
                relatedLocationLatitude: location?.latitude,
                relatedLocationLongitude: location?.longitude,
                relatedLocationLabel: location?.userDisplayName,
                actor: actorId
            )
        }
        dismiss()
    }

    private static func locationSelectionId(for note: Note?, locations: [LocationPing]) -> UUID? {
        guard let note else { return nil }
        return locations.first {
            $0.latitude == note.relatedLocationLatitude &&
            $0.longitude == note.relatedLocationLongitude
        }?.id
    }
}

#Preview("Note Editor - New") {
    let preview = NotesPreviewFactory.make()

    NoteEditorView(
        noteStore: preview.store,
        folders: preview.folders,
        incidents: preview.incidents,
        locations: preview.locations,
        savedPlaces: preview.savedPlaces,
        actorId: preview.user.id
    )
    .modelContainer(preview.container)
}

#Preview("Note Editor - Edit") {
    let preview = NotesPreviewFactory.make()

    NoteEditorView(
        noteStore: preview.store,
        note: preview.note,
        folders: preview.folders,
        incidents: preview.incidents,
        locations: preview.locations,
        savedPlaces: preview.savedPlaces,
        actorId: preview.user.id
    )
    .modelContainer(preview.container)
}
