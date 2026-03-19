//
//  NoteEditorView.swift
//  ufo
//
//  Created by Marcin Ryzko on 17/03/2026.
//

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

struct NoteEditorView: View {
    private let horizontalScreenPadding: CGFloat = 16

    @Environment(\.dismiss) private var dismiss

    let noteStore: NoteStore
    let note: Note?
    let folders: [NoteFolder]
    let incidents: [Incident]
    let locations: [LocationPing]
    let savedPlaces: [SavedPlace]
    let actorId: UUID?

    @State private var title: String
    @State private var richText: NSAttributedString
    @State private var selectedRange: NSRange
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
    @State private var isPreviewMode = false
    @FocusState private var isTitleFocused: Bool

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
        _richText = State(initialValue: NoteRichTextCodec.makeEditorText(from: note?.content ?? ""))
        _selectedRange = State(initialValue: NSRange(location: 0, length: 0))
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
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    titleSection
                    editorSection
                    metadataSection
                }
                .frame(width: max(proxy.size.width - (horizontalScreenPadding * 2), 0), alignment: .leading)
                .padding(.horizontal, horizontalScreenPadding)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }
            .frame(width: proxy.size.width, alignment: .leading)
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(note == nil ? "Nowa notatka" : "Edytuj notatkę")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Wstecz") { dismiss() }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isPreviewMode.toggle()
                    } label: {
                        Image(systemName: isPreviewMode ? "pencil" : "eye")
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .safeAreaInset(edge: .bottom) {
                formattingBar
            }
            .onAppear {
                isTitleFocused = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Tytuł", text: $title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .focused($isTitleFocused)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    noteMetaBadge(title: note == nil ? "Nowa notatka" : "Edytujesz notatkę", systemImage: "square.and.pencil")
                    if isPinned {
                        noteMetaBadge(title: "Przypięta", systemImage: "pin.fill")
                    }
                    if !richText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        noteMetaBadge(title: "Formatowanie aktywne", systemImage: "textformat")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Treść")
                .font(.headline)

            Group {
                if isPreviewMode {
                    NoteRichTextEditorRepresentable(
                        attributedText: .constant(richText),
                        selectedRange: .constant(NSRange(location: 0, length: 0)),
                        isEditable: false
                    )
                    .frame(minHeight: 320)
                } else {
                    ZStack(alignment: .topLeading) {
                        if richText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Zacznij pisać. Formatowanie działa wizualnie, a znaczniki markdown zapisujemy dopiero w tle.")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 18)
                        }

                        NoteRichTextEditorRepresentable(
                            attributedText: $richText,
                            selectedRange: $selectedRange,
                            isEditable: true
                        )
                        .frame(minHeight: 320)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Szczegóły notatki")
                .font(.headline)

            metadataCard(title: "Organizacja", systemImage: "folder") {
                VStack(spacing: 14) {
                    metadataMenuRow(
                        title: "Folder",
                        value: folderTitle(for: selectedFolderId)
                    ) {
                        Picker("Folder", selection: $selectedFolderId) {
                            Text("Bez folderu").tag(UUID?.none)
                            ForEach(folders) { folder in
                                Text(folder.name).tag(UUID?.some(folder.id))
                            }
                        }
                    }

                    Toggle("Przypnij notatkę", isOn: $isPinned)

                    metadataTextField(
                        title: "Tagi",
                        placeholder: "Dom, praca, ważne",
                        text: $tagsText
                    )
                }
            }

            metadataCard(title: "Linki i miejsce", systemImage: "link") {
                VStack(spacing: 14) {
                    metadataTextField(
                        title: "Link",
                        placeholder: "https://...",
                        text: $attachedLinkURL,
                        disableAutocorrection: true,
                        disableCapitalization: true
                    )

                    metadataMenuRow(
                        title: "Zapisane miejsce",
                        value: savedPlaceTitle(for: savedPlaceId)
                    ) {
                        Picker("Zapisane miejsce", selection: $savedPlaceId) {
                            Text("Bez miejsca").tag(UUID?.none)
                            ForEach(savedPlaces) { place in
                                Text(place.name).tag(UUID?.some(place.id))
                            }
                        }
                    }
                }
            }

            metadataCard(title: "Powiązania", systemImage: "point.3.connected.trianglepath.dotted") {
                VStack(spacing: 14) {
                    metadataMenuRow(
                        title: "Typ powiązania",
                        value: linkedEntityType?.localizedLabel ?? "Bez powiązania"
                    ) {
                        Picker("Typ powiązania", selection: $linkedEntityType) {
                            Text("Bez powiązania").tag(NoteLinkedEntityType?.none)
                            ForEach(NoteLinkedEntityType.allCases) { type in
                                Text(type.localizedLabel).tag(NoteLinkedEntityType?.some(type))
                            }
                        }
                    }

                    if linkedEntityType != nil {
                        metadataTextField(
                            title: "ID obiektu",
                            placeholder: "UUID powiązanego obiektu",
                            text: $linkedEntityIdText,
                            disableAutocorrection: true,
                            disableCapitalization: true
                        )
                    }

                    metadataMenuRow(
                        title: "Incydent",
                        value: incidentTitle(for: selectedIncidentId)
                    ) {
                        Picker("Incydent", selection: $selectedIncidentId) {
                            Text("Bez incydentu").tag(UUID?.none)
                            ForEach(incidents) { incident in
                                Text(incident.title).tag(UUID?.some(incident.id))
                            }
                        }
                    }

                    metadataMenuRow(
                        title: "Lokalizacja",
                        value: locationTitle(for: selectedLocationId)
                    ) {
                        Picker("Lokalizacja", selection: $selectedLocationId) {
                            Text("Bez lokalizacji").tag(UUID?.none)
                            ForEach(locations) { location in
                                Text("\(location.userDisplayName) · \(location.recordedAt.formatted(date: .abbreviated, time: .shortened))")
                                    .tag(UUID?.some(location.id))
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formattingBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                formatButton("Nagłówek", systemImage: "textformat.size.larger") {
                    applyBlockStyle(.heading)
                }
                formatButton("Pogrub", systemImage: "bold") {
                    toggleInlineStyle(.bold)
                }
                formatButton("Lista", systemImage: "list.bullet") {
                    applyBlockStyle(.bullet)
                }
                formatButton("Checklista", systemImage: "checklist") {
                    applyBlockStyle(.checklistUnchecked)
                }
                formatButton("Cytat", systemImage: "text.quote") {
                    applyBlockStyle(.quote)
                }
                formatButton("Kod", systemImage: "chevron.left.forwardslash.chevron.right") {
                    toggleInlineStyle(.inlineCode)
                }
                formatButton(isPreviewMode ? "Edytuj" : "Podgląd", systemImage: isPreviewMode ? "pencil" : "eye") {
                    isPreviewMode.toggle()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.thinMaterial)
    }

    private func metadataCard<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func metadataMenuRow<Content: View>(title: String, value: String, @ViewBuilder picker: () -> Content) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            Spacer()

            picker()
                .labelsHidden()
                .pickerStyle(.menu)
        }
    }

    private func metadataTextField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        disableAutocorrection: Bool = false,
        disableCapitalization: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(placeholder, text: text)
#if os(iOS)
                .textInputAutocapitalization(disableCapitalization ? .never : .sentences)
#endif
                .autocorrectionDisabled(disableAutocorrection)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func formatButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func noteMetaBadge(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground), in: Capsule())
    }

    private func applyBlockStyle(_ style: NoteBlockStyle) {
        let mutable = NSMutableAttributedString(attributedString: richText)
        let safeRange = sanitizedSelection(in: mutable)

        if mutable.length == 0 {
            let targetStyle: NoteBlockStyle = style == .body ? .body : style
            let seedText = NoteRichTextCodec.makeEditorText(from: targetStyle.markdownPrefix)
            richText = seedText
            selectedRange = NSRange(location: seedText.length, length: 0)
            return
        }

        let paragraphRanges = NoteRichTextCodec.paragraphRangesCovering(selection: safeRange, in: mutable)
        guard !paragraphRanges.isEmpty else { return }

        let currentStyles = paragraphRanges.map { NoteRichTextCodec.blockStyle(in: mutable, at: $0.location) }
        let targetStyle: NoteBlockStyle = currentStyles.allSatisfy { $0 == style } ? .body : style

        var selectionStart: Int?
        var selectionEnd: Int?

        for paragraphRange in paragraphRanges.reversed() {
            let paragraph = NSMutableAttributedString(attributedString: mutable.attributedSubstring(from: paragraphRange))
            let hadNewline = paragraph.string.hasSuffix("\n")
            if hadNewline {
                paragraph.deleteCharacters(in: NSRange(location: max(paragraph.length - 1, 0), length: 1))
            }

            NoteRichTextCodec.removeEditorPrefix(from: paragraph)
            if !targetStyle.editorPrefix.isEmpty {
                paragraph.insert(
                    NSAttributedString(
                        string: targetStyle.editorPrefix,
                        attributes: NoteRichTextCodec.attributes(for: targetStyle, bold: false, inlineCode: false, isPrefix: true)
                    ),
                    at: 0
                )
            }

            if hadNewline {
                paragraph.append(NSAttributedString(string: "\n", attributes: NoteRichTextCodec.attributes(for: targetStyle)))
            }

            mutable.replaceCharacters(in: paragraphRange, with: paragraph)
            let contentLength = hadNewline ? max(paragraph.length - 1, 0) : paragraph.length
            let replacementRange = NSRange(location: paragraphRange.location, length: contentLength)
            NoteRichTextCodec.restyleParagraph(in: mutable, range: replacementRange, blockStyle: targetStyle)

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

    private func toggleInlineStyle(_ style: NoteInlineStyle) {
        let mutable = NSMutableAttributedString(attributedString: richText)
        let effectiveRange = NoteRichTextCodec.effectiveInlineRange(for: sanitizedSelection(in: mutable), in: mutable)
        guard effectiveRange.length > 0 else { return }

        let shouldEnable = !NoteRichTextCodec.isInlineStyleFullyEnabled(style, in: mutable, range: effectiveRange)
        NoteRichTextCodec.setInlineStyle(style, enabled: shouldEnable, in: mutable, range: effectiveRange)

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
        let linkedEntityId = UUID(uuidString: linkedEntityIdText.trimmingCharacters(in: .whitespacesAndNewlines))
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let markdownContent = NoteRichTextCodec.makeMarkdown(from: richText)

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
        } else {
            await noteStore.addNote(
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
        }
        dismiss()
    }

    private func folderTitle(for id: UUID?) -> String {
        folders.first(where: { $0.id == id })?.name ?? "Bez folderu"
    }

    private func savedPlaceTitle(for id: UUID?) -> String {
        savedPlaces.first(where: { $0.id == id })?.name ?? "Bez miejsca"
    }

    private func incidentTitle(for id: UUID?) -> String {
        incidents.first(where: { $0.id == id })?.title ?? "Bez incydentu"
    }

    private func locationTitle(for id: UUID?) -> String {
        guard let id, let location = locations.first(where: { $0.id == id }) else {
            return "Bez lokalizacji"
        }
        return "\(location.userDisplayName) · \(location.recordedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    private static func locationSelectionId(for note: Note?, locations: [LocationPing]) -> UUID? {
        guard let note else { return nil }
        return locations.first {
            $0.latitude == note.relatedLocationLatitude &&
            $0.longitude == note.relatedLocationLongitude
        }?.id
    }
}

private enum NoteInlineStyle {
    case bold
    case inlineCode
}

private enum NoteBlockStyle: String {
    case body
    case heading
    case bullet
    case checklistUnchecked
    case quote

    var editorPrefix: String {
        switch self {
        case .body, .heading:
            return ""
        case .bullet:
            return "• "
        case .checklistUnchecked:
            return "☐ "
        case .quote:
            return "▌ "
        }
    }

    var markdownPrefix: String {
        switch self {
        case .body:
            return ""
        case .heading:
            return "## "
        case .bullet:
            return "- "
        case .checklistUnchecked:
            return "- [ ] "
        case .quote:
            return "> "
        }
    }

    var editorPrefixLength: Int {
        editorPrefix.utf16.count
    }

    var supportsContinuation: Bool {
        switch self {
        case .bullet, .checklistUnchecked, .quote:
            return true
        case .body, .heading:
            return false
        }
    }
}

private enum NoteRichTextCodec {
    static func makeEditorText(from markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            let (style, content) = blockStyleAndContent(for: line)
            result.append(makeParagraph(content: content, style: style))

            if index < lines.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: attributes(for: style)))
            }
        }

        if result.length == 0 {
            return NSAttributedString(string: "", attributes: attributes(for: .body))
        }

        return result
    }

    static func makeMarkdown(from attributedText: NSAttributedString) -> String {
        guard attributedText.length > 0 else { return "" }

        let fullString = attributedText.string as NSString
        var lines: [String] = []
        var location = 0

        while location < fullString.length {
            let paragraphRange = fullString.paragraphRange(for: NSRange(location: location, length: 0))
            let paragraph = NSMutableAttributedString(attributedString: attributedText.attributedSubstring(from: paragraphRange))
            let hasTrailingNewline = paragraph.string.hasSuffix("\n")

            if hasTrailingNewline {
                paragraph.deleteCharacters(in: NSRange(location: max(paragraph.length - 1, 0), length: 1))
            }

            let style = blockStyle(in: paragraph, at: 0)
            removeEditorPrefix(from: paragraph)
            lines.append(style.markdownPrefix + inlineMarkdown(from: paragraph))

            location = paragraphRange.location + paragraphRange.length
        }

        return lines.joined(separator: "\n")
    }

    static func paragraphRangesCovering(selection: NSRange, in text: NSAttributedString) -> [NSRange] {
        let nsString = text.string as NSString
        guard nsString.length > 0 else { return [NSRange(location: 0, length: 0)] }

        let safeLocation = min(max(selection.location, 0), nsString.length)
        let safeLength = min(max(selection.length, 0), max(nsString.length - safeLocation, 0))

        let firstParagraph = nsString.paragraphRange(for: NSRange(location: min(safeLocation, max(nsString.length - 1, 0)), length: 0))
        var combined = firstParagraph

        if safeLength > 0 {
            let lastTouchedLocation = max(safeLocation + safeLength - 1, safeLocation)
            let clampedLastTouchedLocation = min(lastTouchedLocation, max(nsString.length - 1, 0))
            combined = NSUnionRange(combined, nsString.paragraphRange(for: NSRange(location: clampedLastTouchedLocation, length: 0)))

            let selectedSubstring = nsString.substring(with: NSRange(location: safeLocation, length: safeLength))
            let trailingNewlineCount = selectedSubstring.reversed().prefix { $0 == "\n" }.count
            if trailingNewlineCount > 0 {
                var cursor = combined.location + combined.length
                for _ in 0..<trailingNewlineCount {
                    guard cursor < nsString.length else { break }
                    let nextParagraph = nsString.paragraphRange(for: NSRange(location: cursor, length: 0))
                    combined = NSUnionRange(combined, nextParagraph)
                    cursor = nextParagraph.location + nextParagraph.length
                }
            }
        }

        var ranges: [NSRange] = []
        var cursor = combined.location
        let end = combined.location + combined.length
        while cursor < end {
            let paragraphRange = nsString.paragraphRange(for: NSRange(location: cursor, length: 0))
            ranges.append(paragraphRange)
            cursor = paragraphRange.location + max(paragraphRange.length, 1)
        }

        return ranges
    }

    static func effectiveInlineRange(for selectedRange: NSRange, in text: NSAttributedString) -> NSRange {
        guard text.length > 0 else { return NSRange(location: 0, length: 0) }
        if selectedRange.length > 0 {
            return selectedRange
        }

        let string = text.string as NSString
        let clampedLocation = min(max(selectedRange.location, 0), max(string.length - 1, 0))
        let separators = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)

        var start = clampedLocation
        while start > 0 {
            let value = string.character(at: start - 1)
            if let scalar = UnicodeScalar(Int(value)), separators.contains(scalar) {
                break
            }
            start -= 1
        }

        var end = clampedLocation
        while end < string.length {
            let value = string.character(at: end)
            if let scalar = UnicodeScalar(Int(value)), separators.contains(scalar) {
                break
            }
            end += 1
        }

        return NSRange(location: start, length: max(end - start, 0))
    }

    static func isInlineStyleFullyEnabled(_ style: NoteInlineStyle, in text: NSMutableAttributedString, range: NSRange) -> Bool {
        guard range.length > 0 else { return false }
        let key = style == .bold ? NSAttributedString.Key.noteBold : NSAttributedString.Key.noteInlineCode
        var isEnabledEverywhere = true

        text.enumerateAttribute(key, in: range) { value, _, stop in
            if (value as? Bool) != true {
                isEnabledEverywhere = false
                stop.pointee = true
            }
        }

        return isEnabledEverywhere
    }

    static func setInlineStyle(_ style: NoteInlineStyle, enabled: Bool, in text: NSMutableAttributedString, range: NSRange) {
        let key = style == .bold ? NSAttributedString.Key.noteBold : NSAttributedString.Key.noteInlineCode
        text.addAttribute(key, value: enabled, range: range)
        restyleParagraphsIntersecting(in: text, range: range)
    }

    static func restyleParagraph(in text: NSMutableAttributedString, range: NSRange, blockStyle: NoteBlockStyle) {
        guard range.length >= 0 else { return }
        text.addAttribute(.noteBlockStyle, value: blockStyle.rawValue, range: range)

        if blockStyle.editorPrefixLength > 0, text.string.count >= blockStyle.editorPrefixLength {
            let prefixRange = NSRange(location: range.location, length: min(blockStyle.editorPrefixLength, range.length))
            if prefixRange.length > 0 {
                text.setAttributes(attributes(for: blockStyle, bold: false, inlineCode: false, isPrefix: true), range: prefixRange)
            }
        }

        let contentRange = NSRange(
            location: range.location + blockStyle.editorPrefixLength,
            length: max(range.length - blockStyle.editorPrefixLength, 0)
        )

        guard contentRange.length > 0 else { return }

        text.enumerateAttributes(in: contentRange) { attrs, runRange, _ in
            let isBold = (attrs[.noteBold] as? Bool) == true
            let isCode = (attrs[.noteInlineCode] as? Bool) == true
            text.setAttributes(attributes(for: blockStyle, bold: isBold, inlineCode: isCode), range: runRange)
        }
    }

    static func restyleParagraphsIntersecting(in text: NSMutableAttributedString, range: NSRange) {
        let nsString = text.string as NSString
        let safeLocation = min(max(range.location, 0), nsString.length)
        let safeLength = min(max(range.length, 0), max(nsString.length - safeLocation, 0))
        let safeRange = NSRange(location: safeLocation, length: safeLength)
        let firstParagraph = nsString.paragraphRange(for: NSRange(location: safeRange.location, length: 0))
        let lastLocation = min(max(safeRange.location + max(safeRange.length - 1, 0), 0), max(nsString.length - 1, 0))
        let lastParagraph = nsString.paragraphRange(for: NSRange(location: lastLocation, length: 0))
        let combined = NSUnionRange(firstParagraph, lastParagraph)

        var cursor = combined.location
        while cursor < combined.location + combined.length {
            let paragraphRange = nsString.paragraphRange(for: NSRange(location: cursor, length: 0))
            let hasTrailingNewline = nsString.substring(with: paragraphRange).hasSuffix("\n")
            let effectiveRange = NSRange(
                location: paragraphRange.location,
                length: hasTrailingNewline ? max(paragraphRange.length - 1, 0) : paragraphRange.length
            )
            let style = blockStyle(in: text, at: effectiveRange.location)
            restyleParagraph(in: text, range: effectiveRange, blockStyle: style)
            cursor = paragraphRange.location + max(paragraphRange.length, 1)
        }
    }

    static func blockStyle(in text: NSAttributedString, at location: Int) -> NoteBlockStyle {
        guard text.length > 0 else { return .body }
        let clampedLocation = min(max(location, 0), text.length - 1)
        if let raw = text.attribute(.noteBlockStyle, at: clampedLocation, effectiveRange: nil) as? String,
           let style = NoteBlockStyle(rawValue: raw) {
            return style
        }

        let plain = text.string
        if plain.hasPrefix(NoteBlockStyle.bullet.editorPrefix) {
            return .bullet
        }
        if plain.hasPrefix(NoteBlockStyle.checklistUnchecked.editorPrefix) {
            return .checklistUnchecked
        }
        if plain.hasPrefix(NoteBlockStyle.quote.editorPrefix) {
            return .quote
        }
        return .body
    }

    static func removeEditorPrefix(from text: NSMutableAttributedString) {
        for style in [NoteBlockStyle.checklistUnchecked, .bullet, .quote] {
            if text.string.hasPrefix(style.editorPrefix) {
                text.deleteCharacters(in: NSRange(location: 0, length: style.editorPrefixLength))
                return
            }
        }
    }

    static func contentText(for text: NSAttributedString) -> String {
        let mutable = NSMutableAttributedString(attributedString: text)
        removeEditorPrefix(from: mutable)
        return mutable.string
    }

    static func attributes(for style: NoteBlockStyle, bold: Bool = false, inlineCode: Bool = false, isPrefix: Bool = false) -> [NSAttributedString.Key: Any] {
        var values: [NSAttributedString.Key: Any] = [
            .font: font(for: style, bold: bold, inlineCode: inlineCode, isPrefix: isPrefix),
            .foregroundColor: style == .quote ? UIColor.secondaryLabel : UIColor.label,
            .noteBlockStyle: style.rawValue,
            .noteBold: bold,
            .noteInlineCode: inlineCode
        ]

        if inlineCode && !isPrefix {
            values[.backgroundColor] = UIColor.secondarySystemFill
        }

        return values
    }

    private static func blockStyleAndContent(for line: String) -> (NoteBlockStyle, String) {
        if let match = line.range(of: #"^#{1,6}\s+"#, options: .regularExpression) {
            return (.heading, String(line[match.upperBound...]))
        }
        if line.hasPrefix("- [ ] ") {
            return (.checklistUnchecked, String(line.dropFirst(6)))
        }
        if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
            return (.checklistUnchecked, String(line.dropFirst(6)))
        }
        if line.hasPrefix("- ") {
            return (.bullet, String(line.dropFirst(2)))
        }
        if line.hasPrefix("* ") {
            return (.bullet, String(line.dropFirst(2)))
        }
        if line.hasPrefix("> ") {
            return (.quote, String(line.dropFirst(2)))
        }
        return (.body, line)
    }

    private static func makeParagraph(content: String, style: NoteBlockStyle) -> NSAttributedString {
        let result = NSMutableAttributedString()

        if !style.editorPrefix.isEmpty {
            result.append(NSAttributedString(
                string: style.editorPrefix,
                attributes: attributes(for: style, isPrefix: true)
            ))
        }

        result.append(parseInlineMarkdown(content, style: style))
        if result.length == 0 {
            result.append(NSAttributedString(string: "", attributes: attributes(for: style)))
        }
        return result
    }

    private static func parseInlineMarkdown(_ content: String, style: NoteBlockStyle) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var index = content.startIndex

        while index < content.endIndex {
            if content[index...].hasPrefix("**"),
               let closing = content[index...].dropFirst(2).range(of: "**") {
                let start = content.index(index, offsetBy: 2)
                let fragment = String(content[start..<closing.lowerBound])
                result.append(NSAttributedString(
                    string: fragment,
                    attributes: attributes(for: style, bold: true)
                ))
                index = closing.upperBound
                continue
            }

            if content[index] == "`",
               let closing = content[content.index(after: index)...].firstIndex(of: "`") {
                let start = content.index(after: index)
                let fragment = String(content[start..<closing])
                result.append(NSAttributedString(
                    string: fragment,
                    attributes: attributes(for: style, inlineCode: true)
                ))
                index = content.index(after: closing)
                continue
            }

            let nextSpecial = nextSpecialIndex(in: content, from: index)
            let fragment = String(content[index..<nextSpecial])
            result.append(NSAttributedString(
                string: fragment,
                attributes: attributes(for: style)
            ))
            index = nextSpecial
        }

        return result
    }

    private static func nextSpecialIndex(in string: String, from index: String.Index) -> String.Index {
        var cursor = index
        while cursor < string.endIndex {
            if string[cursor...].hasPrefix("**") || string[cursor] == "`" {
                return cursor
            }
            cursor = string.index(after: cursor)
        }
        return string.endIndex
    }

    private static func inlineMarkdown(from text: NSAttributedString) -> String {
        guard text.length > 0 else { return "" }
        var result = ""

        text.enumerateAttributes(in: NSRange(location: 0, length: text.length)) { attrs, range, _ in
            let fragment = escapedMarkdown(text.attributedSubstring(from: range).string)
            let isBold = (attrs[.noteBold] as? Bool) == true
            let isCode = (attrs[.noteInlineCode] as? Bool) == true

            if isCode {
                result += "`\(fragment)`"
            } else if isBold {
                result += "**\(fragment)**"
            } else {
                result += fragment
            }
        }

        return result
    }

    private static func escapedMarkdown(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "*", with: "\\*")
    }

    private static func font(for style: NoteBlockStyle, bold: Bool, inlineCode: Bool, isPrefix: Bool) -> UIFont {
        let size: CGFloat
        switch style {
        case .heading:
            size = 30
        default:
            size = 19
        }

        if inlineCode && !isPrefix {
            return .monospacedSystemFont(ofSize: max(size - 1, 16), weight: bold ? .semibold : .regular)
        }

        let weight: UIFont.Weight = (bold || style == .heading) ? .bold : .regular
        var font = UIFont.systemFont(ofSize: size, weight: weight)

        if style == .quote && !isPrefix {
            if let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic) {
                font = UIFont(descriptor: descriptor, size: size)
            }
        }

        return font
    }
}

private extension NSAttributedString.Key {
    static let noteBlockStyle = NSAttributedString.Key("ufo.noteBlockStyle")
    static let noteBold = NSAttributedString.Key("ufo.noteBold")
    static let noteInlineCode = NSAttributedString.Key("ufo.noteInlineCode")
}

#if os(iOS)
private struct NoteRichTextEditorRepresentable: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    @Binding var selectedRange: NSRange
    let isEditable: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.adjustsFontForContentSizeCategory = true
        textView.textContainerInset = UIEdgeInsets(top: 18, left: 14, bottom: 18, right: 14)
        textView.textContainer.lineFragmentPadding = 0
        textView.keyboardDismissMode = .interactive
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.attributedText = attributedText
        return textView
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let targetWidth = proposal.width ?? UIScreen.main.bounds.width
        let fittingSize = CGSize(width: targetWidth, height: .greatestFiniteMagnitude)
        let size = uiView.sizeThatFits(fittingSize)
        return CGSize(width: targetWidth, height: size.height)
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.isEditable = isEditable

        if !uiView.attributedText.isEqual(attributedText) {
            let wasFirstResponder = uiView.isFirstResponder
            uiView.attributedText = attributedText
            if wasFirstResponder {
                uiView.becomeFirstResponder()
            }
        }

        let safeLocation = min(max(selectedRange.location, 0), uiView.attributedText.length)
        let safeLength = min(max(selectedRange.length, 0), max(uiView.attributedText.length - safeLocation, 0))
        let safeRange = NSRange(location: safeLocation, length: safeLength)

        if uiView.selectedRange != safeRange {
            uiView.selectedRange = safeRange
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: NoteRichTextEditorRepresentable

        init(_ parent: NoteRichTextEditorRepresentable) {
            self.parent = parent
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard parent.isEditable, text == "\n", range.length == 0 else { return true }

            let mutable = NSMutableAttributedString(attributedString: textView.attributedText ?? NSAttributedString())
            guard mutable.length > 0 else { return true }

            let nsString = mutable.string as NSString
            let safeLocation = min(max(range.location, 0), mutable.length)
            let paragraphRange = nsString.paragraphRange(for: NSRange(location: min(safeLocation, max(mutable.length - 1, 0)), length: 0))
            let style = NoteRichTextCodec.blockStyle(in: mutable, at: paragraphRange.location)

            guard style.supportsContinuation else { return true }

            let paragraph = NSMutableAttributedString(attributedString: mutable.attributedSubstring(from: paragraphRange))
            let hasTrailingNewline = paragraph.string.hasSuffix("\n")
            if hasTrailingNewline {
                paragraph.deleteCharacters(in: NSRange(location: max(paragraph.length - 1, 0), length: 1))
            }

            let contentText = NoteRichTextCodec.contentText(for: paragraph).trimmingCharacters(in: .whitespacesAndNewlines)

            if contentText.isEmpty {
                mutable.replaceCharacters(in: paragraphRange, with: NSAttributedString(string: "\n", attributes: NoteRichTextCodec.attributes(for: .body)))
                textView.attributedText = mutable
                textView.selectedRange = NSRange(location: paragraphRange.location, length: 0)
                textViewDidChange(textView)
                textViewDidChangeSelection(textView)
                return false
            }

            let insertion = NSMutableAttributedString(
                string: "\n" + style.editorPrefix,
                attributes: NoteRichTextCodec.attributes(for: style)
            )
            if style.editorPrefixLength > 0 {
                insertion.setAttributes(
                    NoteRichTextCodec.attributes(for: style, isPrefix: true),
                    range: NSRange(location: 1, length: style.editorPrefixLength)
                )
            }

            mutable.replaceCharacters(in: range, with: insertion)
            let affectedRange = NSRange(location: paragraphRange.location, length: paragraphRange.length + insertion.length)
            NoteRichTextCodec.restyleParagraphsIntersecting(in: mutable, range: affectedRange)

            textView.attributedText = mutable
            textView.selectedRange = NSRange(location: safeLocation + insertion.length, length: 0)
            textViewDidChange(textView)
            textViewDidChangeSelection(textView)
            return false
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.attributedText = textView.attributedText ?? NSAttributedString(string: "")
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.selectedRange = textView.selectedRange
        }
    }
}
#endif

#Preview("Note Editor - New") {
    let preview = NotesPreviewFactory.make()

    NavigationStack {
        NoteEditorView(
            noteStore: preview.store,
            folders: preview.folders,
            incidents: preview.incidents,
            locations: preview.locations,
            savedPlaces: preview.savedPlaces,
            actorId: preview.user.id
        )
    }
    .modelContainer(preview.container)
}

#Preview("Note Editor - Edit") {
    let preview = NotesPreviewFactory.make()

    NavigationStack {
        NoteEditorView(
            noteStore: preview.store,
            note: preview.note,
            folders: preview.folders,
            incidents: preview.incidents,
            locations: preview.locations,
            savedPlaces: preview.savedPlaces,
            actorId: preview.user.id
        )
    }
    .modelContainer(preview.container)
}
