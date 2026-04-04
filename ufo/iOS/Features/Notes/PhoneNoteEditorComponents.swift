#if os(iOS)

//
//  NoteEditorComponents.swift
//  ufo
//
//  Created by Codex on 22/03/2026.
//

import SwiftUI

struct PhoneNoteEditorHeaderSection: View {
    @Binding var title: String
    let isPinned: Bool
    let hasRichText: Bool
    let isEditingExistingNote: Bool
    let subtitle: String
    @FocusState.Binding var isTitleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(subtitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("notes.editor.field.title", text: $title)
                .font(.system(size: 30, weight: .medium, design: .rounded))
                .textFieldStyle(.plain)
                .focused($isTitleFocused)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Color.separatorAdaptive.opacity(0.45))
                .frame(height: 1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    noteMetaBadge(
                        title: String(localized: isEditingExistingNote ? "notes.editor.badge.draft" : "notes.editor.badge.new"),
                        systemImage: "square.and.pencil"
                    )
                    if isPinned {
                        noteMetaBadge(title: String(localized: "notes.editor.badge.pinned"), systemImage: "pin.fill")
                    }
                    if hasRichText {
                        noteMetaBadge(title: String(localized: "notes.editor.badge.richTextActive"), systemImage: "textformat")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func noteMetaBadge(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondarySystemBackgroundAdaptive, in: Capsule())
    }
}

struct PhoneNoteEditorContentSection: View {
    @Binding var richText: NSAttributedString
    @Binding var selectedRange: NSRange
    let isPreviewMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(isPreviewMode ? String(localized: "notes.editor.section.preview") : String(localized: "notes.editor.field.content"))
                    .font(.headline)
                Spacer()
                if isPreviewMode {
                    Label("notes.editor.badge.readOnly", systemImage: "eye")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Group {
                if isPreviewMode {
                    PhoneNoteRichTextEditorRepresentable(
                        attributedText: .constant(richText),
                        selectedRange: .constant(NSRange(location: 0, length: 0)),
                        isEditable: false
                    )
                    .frame(minHeight: 320)
                } else {
                    ZStack(alignment: .topLeading) {
                        if richText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("notes.editor.placeholder.startWriting")
                                .font(.title3.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .allowsHitTesting(false)
                        }

                        PhoneNoteRichTextEditorRepresentable(
                            attributedText: $richText,
                            selectedRange: $selectedRange,
                            isEditable: true
                        )
                        .frame(minHeight: 320)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PhoneNoteEditorMetadataSection: View {
    let folders: [NoteFolder]
    let missions: [Mission]
    let incidents: [Incident]
    let people: [UserProfile]
    let locations: [LocationPing]
    let savedPlaces: [SavedPlace]

    @Binding var selectedFolderId: UUID?
    @Binding var attachedLinkURL: String
    @Binding var tagsText: String
    @Binding var isPinned: Bool
    @Binding var linkedEntityType: NoteLinkedEntityType?
    @Binding var linkedEntityId: UUID?
    @Binding var savedPlaceId: UUID?
    @Binding var selectedIncidentId: UUID?
    @Binding var selectedLocationId: UUID?
    @Binding var isExpanded: Bool
    @Binding var isPresentingAddPlace: Bool
    @Binding var isPresentingAddMission: Bool
    @Binding var isPresentingAddIncident: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 16) {
                metadataCard(title: String(localized: "notes.editor.section.organization"), systemImage: "folder") {
                    VStack(spacing: 14) {
                        SelectionMenuRow(
                            title: String(localized: "notes.editor.field.folder"),
                            value: folderTitle(for: selectedFolderId),
                            isPlaceholder: selectedFolderId == nil
                        ) {
                            Button(String(localized: "notes.editor.action.noFolder")) { selectedFolderId = nil }
                            ForEach(folders) { folder in
                                Button(folder.name) { selectedFolderId = folder.id }
                            }
                        }

                        Toggle("notes.editor.field.pin", isOn: $isPinned)

                        metadataTextField(
                            title: String(localized: "notes.editor.field.tags"),
                            placeholder: String(localized: "notes.editor.placeholder.tags"),
                            text: $tagsText
                        )
                    }
                }

                metadataCard(title: String(localized: "notes.editor.section.linksAndPlace"), systemImage: "link") {
                    VStack(spacing: 14) {
                        metadataTextField(
                            title: String(localized: "notes.editor.field.linkUrl"),
                            placeholder: "https://...",
                            text: $attachedLinkURL,
                            disableAutocorrection: true,
                            disableCapitalization: true
                        )

                        SelectionMenuRow(
                            title: String(localized: "notes.editor.field.savedPlace"),
                            value: savedPlaceTitle(for: savedPlaceId),
                            isPlaceholder: savedPlaceId == nil
                        ) {
                            Button(String(localized: "notes.editor.action.noPlace")) { savedPlaceId = nil }
                            ForEach(savedPlaces) { place in
                                Button(place.name) { savedPlaceId = place.id }
                            }
                            Divider()
                            Button(String(localized: "notes.editor.action.addPlace")) { isPresentingAddPlace = true }
                        }
                    }
                }

                metadataCard(title: String(localized: "notes.editor.section.relationships"), systemImage: "point.3.connected.trianglepath.dotted") {
                    VStack(spacing: 14) {
                        SelectionMenuRow(
                            title: String(localized: "notes.editor.field.relationshipType"),
                            value: linkedEntityType?.localizedLabel ?? String(localized: "notes.editor.action.noRelation"),
                            isPlaceholder: linkedEntityType == nil
                        ) {
                            Button(String(localized: "notes.editor.action.noRelation")) { linkedEntityType = nil }
                            ForEach(NoteLinkedEntityType.allCases) { type in
                                Button(type.localizedLabel) { linkedEntityType = type }
                            }
                        }

                        SelectionMenuRow(
                            title: String(localized: "notes.editor.field.incident"),
                            value: incidentTitle(for: selectedIncidentId),
                            isPlaceholder: selectedIncidentId == nil
                        ) {
                            Button(String(localized: "notes.editor.action.noIncident")) { selectedIncidentId = nil }
                            ForEach(incidents) { incident in
                                Button(incident.title) { selectedIncidentId = incident.id }
                            }
                            Divider()
                            Button(String(localized: "notes.editor.action.addIncident")) { isPresentingAddIncident = true }
                        }

                        if let linkedEntityType {
                            SelectionMenuRow(
                                title: linkedEntityPickerTitle(for: linkedEntityType),
                                value: linkedEntityDisplayValue(for: linkedEntityType, id: linkedEntityId),
                                isPlaceholder: linkedEntityId == nil
                            ) {
                                Button(String(localized: "notes.editor.action.noRelation")) { linkedEntityId = nil }
                                switch linkedEntityType {
                                case .mission:
                                    ForEach(missions) { mission in
                                        Button(mission.title) { linkedEntityId = mission.id }
                                    }
                                    Divider()
                                    Button(String(localized: "notes.editor.action.addMission")) { isPresentingAddMission = true }
                                case .incident:
                                    ForEach(incidents) { incident in
                                        Button(incident.title) { linkedEntityId = incident.id }
                                    }
                                    Divider()
                                    Button(String(localized: "notes.editor.action.addIncident")) { isPresentingAddIncident = true }
                                case .place:
                                    ForEach(savedPlaces) { place in
                                        Button(place.name) { linkedEntityId = place.id }
                                    }
                                    Divider()
                                    Button(String(localized: "notes.editor.action.addPlace")) { isPresentingAddPlace = true }
                                case .person:
                                    ForEach(people) { person in
                                        Button(person.effectiveDisplayName ?? person.email) { linkedEntityId = person.id }
                                    }
                                }
                            }
                        }

                        SelectionMenuRow(
                            title: String(localized: "notes.editor.field.location"),
                            value: locationTitle(for: selectedLocationId),
                            isPlaceholder: selectedLocationId == nil
                        ) {
                            Button(String(localized: "notes.editor.action.noLocation")) { selectedLocationId = nil }
                            ForEach(locations) { location in
                                Button("\(location.userDisplayName) · \(location.recordedAt.formatted(date: .abbreviated, time: .shortened))") {
                                    selectedLocationId = location.id
                                }
                            }
                        }
                    }
                }
            }
            .padding(.top, 14)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("notes.editor.details.title")
                        .font(.headline)
                    Text(isExpanded ? String(localized: "notes.editor.details.collapse") : String(localized: "notes.editor.details.expand"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(18)
            .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.separatorAdaptive.opacity(0.35), lineWidth: 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.separatorAdaptive.opacity(0.4), lineWidth: 1)
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
                .platformTextInputAutocapitalization(disableCapitalization ? .never : .sentences)
                .autocorrectionDisabled(disableAutocorrection)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func folderTitle(for id: UUID?) -> String {
        folders.first(where: { $0.id == id })?.name ?? String(localized: "notes.editor.action.noFolder")
    }

    private func savedPlaceTitle(for id: UUID?) -> String {
        savedPlaces.first(where: { $0.id == id })?.name ?? String(localized: "notes.editor.action.noPlace")
    }

    private func incidentTitle(for id: UUID?) -> String {
        incidents.first(where: { $0.id == id })?.title ?? String(localized: "notes.editor.action.noIncident")
    }

    private func locationTitle(for id: UUID?) -> String {
        guard let id, let location = locations.first(where: { $0.id == id }) else {
            return String(localized: "notes.editor.action.noLocation")
        }
        return "\(location.userDisplayName) · \(location.recordedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    private func linkedEntityPickerTitle(for type: NoteLinkedEntityType) -> String {
        switch type {
        case .mission:
            return String(localized: "notes.editor.related.mission")
        case .incident:
            return String(localized: "notes.editor.related.incident")
        case .place:
            return String(localized: "notes.editor.related.place")
        case .person:
            return String(localized: "notes.editor.related.person")
        }
    }

    private func linkedEntityDisplayValue(for type: NoteLinkedEntityType, id: UUID?) -> String {
        guard let id else { return String(localized: "notes.editor.action.noRelation") }
        switch type {
        case .mission:
            return missions.first(where: { $0.id == id })?.title ?? String(localized: "notes.editor.related.unknownMission")
        case .incident:
            return incidents.first(where: { $0.id == id })?.title ?? String(localized: "notes.editor.related.unknownIncident")
        case .place:
            return savedPlaces.first(where: { $0.id == id })?.name ?? String(localized: "notes.editor.related.unknownPlace")
        case .person:
            return people.first(where: { $0.id == id })?.effectiveDisplayName
                ?? people.first(where: { $0.id == id })?.email
                ?? String(localized: "notes.editor.related.unknownPerson")
        }
    }
}

struct PhoneNoteEditorFormattingBar: View {
    let isPreviewMode: Bool
    let onHeading: () -> Void
    let onBold: () -> Void
    let onBullet: () -> Void
    let onChecklist: () -> Void
    let onQuote: () -> Void
    let onCode: () -> Void
    let onTogglePreview: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                formatButton(String(localized: "notes.editor.format.heading"), systemImage: "textformat.size.larger", action: onHeading)
                formatButton(String(localized: "notes.editor.format.bold"), systemImage: "bold", action: onBold)
                formatButton(String(localized: "notes.editor.format.list"), systemImage: "list.bullet", action: onBullet)
                formatButton(String(localized: "notes.editor.format.checklist"), systemImage: "checklist", action: onChecklist)
                formatButton(String(localized: "notes.editor.format.quote"), systemImage: "text.quote", action: onQuote)
                formatButton(String(localized: "notes.editor.format.code"), systemImage: "chevron.left.forwardslash.chevron.right", action: onCode)
                formatButton(
                    isPreviewMode ? String(localized: "notes.editor.format.edit") : String(localized: "notes.editor.format.preview"),
                    systemImage: isPreviewMode ? "pencil" : "eye",
                    action: onTogglePreview
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.separatorAdaptive.opacity(0.2), lineWidth: 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private func formatButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.secondarySystemBackgroundAdaptive, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

#endif
