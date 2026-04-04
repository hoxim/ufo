#if os(iOS)

//
//  PhoneNoteEditorView.swift
//  ufo
//
//  Created by Marcin Ryzko on 17/03/2026.
//

import SwiftUI
import SwiftData

struct PhoneNoteEditorView: View {
    private let horizontalScreenPadding: CGFloat = 16

    @Environment(\.dismiss) private var dismiss

    let noteStore: NoteStore
    let note: Note?
    let folders: [NoteFolder]
    let missions: [Mission]
    let incidents: [Incident]
    let people: [UserProfile]
    let locations: [LocationPing]
    let savedPlaces: [SavedPlace]
    let actorId: UUID?
    let originLabel: String?
    var onSaved: ((UUID) -> Void)? = nil

    @State private var title: String
    @State private var richText: NSAttributedString
    @State private var selectedRange: NSRange
    @State private var selectedFolderId: UUID?
    @State private var attachedLinkURL: String
    @State private var tagsText: String
    @State private var isPinned: Bool
    @State private var linkedEntityType: NoteLinkedEntityType?
    @State private var linkedEntityId: UUID?
    @State private var savedPlaceId: UUID?
    @State private var selectedIncidentId: UUID?
    @State private var selectedLocationId: UUID?
    @State private var isSaving = false
    @State private var isPreviewMode = false
    @State private var isMetadataExpanded: Bool
    @State private var isPresentingAddPlace = false
    @State private var isPresentingAddMission = false
    @State private var isPresentingAddIncident = false
    @FocusState private var isTitleFocused: Bool

    init(
        noteStore: NoteStore,
        note: Note? = nil,
        folders: [NoteFolder],
        missions: [Mission],
        incidents: [Incident],
        people: [UserProfile],
        locations: [LocationPing],
        savedPlaces: [SavedPlace] = [],
        actorId: UUID?,
        prefillLinkedEntityType: NoteLinkedEntityType? = nil,
        prefillLinkedEntityId: UUID? = nil,
        prefillSavedPlaceId: UUID? = nil,
        prefillSelectedIncidentId: UUID? = nil,
        originLabel: String? = nil,
        onSaved: ((UUID) -> Void)? = nil
    ) {
        self.noteStore = noteStore
        self.note = note
        self.folders = folders
        self.missions = missions
        self.incidents = incidents
        self.people = people
        self.locations = locations
        self.savedPlaces = savedPlaces
        self.actorId = actorId
        self.originLabel = originLabel
        self.onSaved = onSaved
        _title = State(initialValue: note?.title ?? "")
        _richText = State(initialValue: PhoneNoteRichTextCodec.makeEditorText(from: note?.content ?? ""))
        _selectedRange = State(initialValue: NSRange(location: 0, length: 0))
        _selectedFolderId = State(initialValue: note?.folderId)
        _attachedLinkURL = State(initialValue: note?.attachedLinkURL ?? "")
        _tagsText = State(initialValue: note?.resolvedTags.joined(separator: ", ") ?? "")
        _isPinned = State(initialValue: note?.isPinnedValue ?? false)
        _linkedEntityType = State(initialValue: note.flatMap { $0.linkedEntityType }.flatMap(NoteLinkedEntityType.init(rawValue:)) ?? prefillLinkedEntityType)
        _linkedEntityId = State(initialValue: note?.linkedEntityId ?? prefillLinkedEntityId)
        _savedPlaceId = State(initialValue: note?.savedPlaceId ?? prefillSavedPlaceId)
        _selectedIncidentId = State(initialValue: note?.relatedIncidentId ?? prefillSelectedIncidentId)
        _selectedLocationId = State(initialValue: Self.locationSelectionId(for: note, locations: locations))
        _isMetadataExpanded = State(initialValue: note != nil || prefillLinkedEntityId != nil || prefillSavedPlaceId != nil || prefillSelectedIncidentId != nil)
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let originLabel {
                        OpenedFromBadge(title: originLabel)
                    }
                    titleSection
                    editorSection
                    metadataSection
                }
                .frame(maxWidth: 800, alignment: .leading)
                .padding(.horizontal, horizontalScreenPadding)
                .padding(.top, 24)
                .padding(.bottom, 120)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .background(Color.clear)
            .navigationTitle(note == nil ? String(localized: "notes.editor.title.new") : String(localized: "notes.editor.title.edit"))
            .modalInlineTitleDisplayMode()
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ModalCloseToolbarItem {
                    dismiss()
                }

                ModalConfirmToolbarItem(
                    isDisabled: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving,
                    isProcessing: isSaving
                ) {
                    Task { await save() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                formattingBar
            }
            .sheet(isPresented: $isPresentingAddPlace) {
                QuickAddPlaceSheet(originLabel: originLabel ?? defaultOriginLabel) { place in
                    savedPlaceId = place.id
                    if linkedEntityType == .place {
                        linkedEntityId = place.id
                    }
                }
            }
            .sheet(isPresented: $isPresentingAddMission) {
                QuickCreateMissionSheet(
                    initialSavedPlaceId: savedPlaceId,
                    originLabel: originLabel ?? defaultOriginLabel
                ) { missionId in
                    linkedEntityType = .mission
                    linkedEntityId = missionId
                }
            }
            .sheet(isPresented: $isPresentingAddIncident) {
                QuickCreateIncidentSheet(
                    initialRelatedPlaceId: savedPlaceId,
                    originLabel: originLabel ?? defaultOriginLabel
                ) { incidentId in
                    selectedIncidentId = incidentId
                    if linkedEntityType == .incident {
                        linkedEntityId = incidentId
                    }
                }
            }
            .onAppear {
                isTitleFocused = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .onChange(of: linkedEntityType) { oldValue, newValue in
                guard oldValue != newValue else { return }
                linkedEntityId = nil
            }
        }
    }

    private var titleSection: some View {
        PhoneNoteEditorHeaderSection(
            title: $title,
            isPinned: isPinned,
            hasRichText: !richText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            isEditingExistingNote: note != nil,
            subtitle: headerSubtitle,
            isTitleFocused: $isTitleFocused
        )
    }

    private var editorSection: some View {
        PhoneNoteEditorContentSection(
            richText: $richText,
            selectedRange: $selectedRange,
            isPreviewMode: isPreviewMode
        )
    }

    private var metadataSection: some View {
        PhoneNoteEditorMetadataSection(
            folders: folders,
            missions: missions,
            incidents: incidents,
            people: people,
            locations: locations,
            savedPlaces: savedPlaces,
            selectedFolderId: $selectedFolderId,
            attachedLinkURL: $attachedLinkURL,
            tagsText: $tagsText,
            isPinned: $isPinned,
            linkedEntityType: $linkedEntityType,
            linkedEntityId: $linkedEntityId,
            savedPlaceId: $savedPlaceId,
            selectedIncidentId: $selectedIncidentId,
            selectedLocationId: $selectedLocationId,
            isExpanded: $isMetadataExpanded,
            isPresentingAddPlace: $isPresentingAddPlace,
            isPresentingAddMission: $isPresentingAddMission,
            isPresentingAddIncident: $isPresentingAddIncident
        )
    }

    private var formattingBar: some View {
        PhoneNoteEditorFormattingBar(
            isPreviewMode: isPreviewMode,
            onHeading: { applyBlockStyle(.heading) },
            onBold: { toggleInlineStyle(.bold) },
            onBullet: { applyBlockStyle(.bullet) },
            onChecklist: { applyBlockStyle(.checklistUnchecked) },
            onQuote: { applyBlockStyle(.quote) },
            onCode: { toggleInlineStyle(.inlineCode) },
            onTogglePreview: { isPreviewMode.toggle() }
        )
    }

    private var headerSubtitle: String {
        let referenceDate = note?.updatedAt ?? .now
        return referenceDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    private func applyBlockStyle(_ style: PhoneNoteBlockStyle) {
        let mutable = NSMutableAttributedString(attributedString: richText)
        let safeRange = sanitizedSelection(in: mutable)

        if mutable.length == 0 {
            let targetStyle: PhoneNoteBlockStyle = style == .body ? .body : style
            let seedText = PhoneNoteRichTextCodec.makeEditorText(from: targetStyle.markdownPrefix)
            richText = seedText
            selectedRange = NSRange(location: seedText.length, length: 0)
            return
        }

        let paragraphRanges = PhoneNoteRichTextCodec.paragraphRangesCovering(selection: safeRange, in: mutable)
        guard !paragraphRanges.isEmpty else { return }

        let currentStyles = paragraphRanges.map { PhoneNoteRichTextCodec.blockStyle(in: mutable, at: $0.location) }
        let targetStyle: PhoneNoteBlockStyle = currentStyles.allSatisfy { $0 == style } ? .body : style

        var selectionStart: Int?
        var selectionEnd: Int?

        for paragraphRange in paragraphRanges.reversed() {
            let paragraph = NSMutableAttributedString(attributedString: mutable.attributedSubstring(from: paragraphRange))
            let hadNewline = paragraph.string.hasSuffix("\n")
            if hadNewline {
                paragraph.deleteCharacters(in: NSRange(location: max(paragraph.length - 1, 0), length: 1))
            }

            PhoneNoteRichTextCodec.removeEditorPrefix(from: paragraph)
            if !targetStyle.editorPrefix.isEmpty {
                paragraph.insert(
                    NSAttributedString(
                        string: targetStyle.editorPrefix,
                        attributes: PhoneNoteRichTextCodec.attributes(for: targetStyle, bold: false, inlineCode: false, isPrefix: true)
                    ),
                    at: 0
                )
            }

            if hadNewline {
                paragraph.append(NSAttributedString(string: "\n", attributes: PhoneNoteRichTextCodec.attributes(for: targetStyle)))
            }

            mutable.replaceCharacters(in: paragraphRange, with: paragraph)
            let contentLength = hadNewline ? max(paragraph.length - 1, 0) : paragraph.length
            let replacementRange = NSRange(location: paragraphRange.location, length: contentLength)
            PhoneNoteRichTextCodec.restyleParagraph(in: mutable, range: replacementRange, blockStyle: targetStyle)

            let paragraphSelectionStart = paragraphRange.location + targetStyle.editorPrefixLength
            let paragraphSelectionEnd = paragraphRange.location + contentLength

            selectionStart = min(selectionStart ?? paragraphSelectionStart, paragraphSelectionStart)
            selectionEnd = max(selectionEnd ?? paragraphSelectionEnd, paragraphSelectionEnd)
        }

        richText = mutable
        let start = selectionStart ?? safeRange.location
        let end = selectionEnd ?? start
        selectedRange = NSRange(location: start, length: max(end - start, 0))
    }

    private func toggleInlineStyle(_ style: PhoneNoteInlineStyle) {
        let mutable = NSMutableAttributedString(attributedString: richText)
        let effectiveRange = PhoneNoteRichTextCodec.effectiveInlineRange(for: sanitizedSelection(in: mutable), in: mutable)
        guard effectiveRange.length > 0 else { return }

        let shouldEnable = !PhoneNoteRichTextCodec.isInlineStyleFullyEnabled(style, in: mutable, range: effectiveRange)
        PhoneNoteRichTextCodec.setInlineStyle(style, enabled: shouldEnable, in: mutable, range: effectiveRange)

        richText = mutable
        selectedRange = effectiveRange
    }

    private func sanitizedSelection(in text: NSAttributedString) -> NSRange {
        let length = text.length
        let location = min(max(selectedRange.location, 0), length)
        let rangeLength = min(max(selectedRange.length, 0), max(length - location, 0))
        return NSRange(location: location, length: rangeLength)
    }

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
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let markdownContent = PhoneNoteRichTextCodec.makeMarkdown(from: richText)

        if let note {
            await noteStore.updateNote(
                note,
                title: cleanTitle,
                content: markdownContent,
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
            onSaved?(note.id)
        } else {
            let createdNote = await noteStore.addNote(
                title: cleanTitle,
                content: markdownContent,
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
            if let createdNote {
                onSaved?(createdNote.id)
            }
        }
        dismiss()
    }

    private var defaultOriginLabel: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "note draft" : trimmed
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
    let preview = PhoneNotesPreviewFactory.make()

    NavigationStack {
        PhoneNoteEditorView(
            noteStore: preview.store,
            folders: preview.folders,
            missions: preview.missions,
            incidents: preview.incidents,
            people: preview.people,
            locations: preview.locations,
            savedPlaces: preview.savedPlaces,
            actorId: preview.user.id
        )
    }
    .modelContainer(preview.container)
}

#Preview("Note Editor - Edit") {
    let preview = PhoneNotesPreviewFactory.make()

    NavigationStack {
        PhoneNoteEditorView(
            noteStore: preview.store,
            note: preview.note,
            folders: preview.folders,
            missions: preview.missions,
            incidents: preview.incidents,
            people: preview.people,
            locations: preview.locations,
            savedPlaces: preview.savedPlaces,
            actorId: preview.user.id
        )
    }
    .modelContainer(preview.container)
}

#endif
