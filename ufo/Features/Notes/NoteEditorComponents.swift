//
//  NoteEditorComponents.swift
//  ufo
//
//  Created by Codex on 22/03/2026.
//

import SwiftUI

struct NoteEditorHeaderSection: View {
    @Binding var title: String
    let isPinned: Bool
    let hasRichText: Bool
    let isEditingExistingNote: Bool
    @FocusState.Binding var isTitleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Tytuł", text: $title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .focused($isTitleFocused)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    noteMetaBadge(
                        title: isEditingExistingNote ? "Edytujesz notatkę" : "Nowa notatka",
                        systemImage: "square.and.pencil"
                    )
                    if isPinned {
                        noteMetaBadge(title: "Przypięta", systemImage: "pin.fill")
                    }
                    if hasRichText {
                        noteMetaBadge(title: "Formatowanie aktywne", systemImage: "textformat")
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
            .background(Color(.secondarySystemBackground), in: Capsule())
    }
}

struct NoteEditorContentSection: View {
    @Binding var richText: NSAttributedString
    @Binding var selectedRange: NSRange
    let isPreviewMode: Bool

    var body: some View {
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
}

struct NoteEditorMetadataSection: View {
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
    @Binding var isPresentingAddPlace: Bool
    @Binding var isPresentingAddMission: Bool
    @Binding var isPresentingAddIncident: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Szczegóły notatki")
                .font(.headline)

            metadataCard(title: "Organizacja", systemImage: "folder") {
                VStack(spacing: 14) {
                    SelectionMenuRow(
                        title: "Folder",
                        value: folderTitle(for: selectedFolderId),
                        isPlaceholder: selectedFolderId == nil
                    ) {
                        Button("Bez folderu") { selectedFolderId = nil }
                        ForEach(folders) { folder in
                            Button(folder.name) { selectedFolderId = folder.id }
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

                    SelectionMenuRow(
                        title: "Zapisane miejsce",
                        value: savedPlaceTitle(for: savedPlaceId),
                        isPlaceholder: savedPlaceId == nil
                    ) {
                        Button("Bez miejsca") { savedPlaceId = nil }
                        ForEach(savedPlaces) { place in
                            Button(place.name) { savedPlaceId = place.id }
                        }
                        Divider()
                        Button("Add new place") { isPresentingAddPlace = true }
                    }
                }
            }

            metadataCard(title: "Powiązania", systemImage: "point.3.connected.trianglepath.dotted") {
                VStack(spacing: 14) {
                    SelectionMenuRow(
                        title: "Typ powiązania",
                        value: linkedEntityType?.localizedLabel ?? "Bez powiązania",
                        isPlaceholder: linkedEntityType == nil
                    ) {
                        Button("Bez powiązania") { linkedEntityType = nil }
                        ForEach(NoteLinkedEntityType.allCases) { type in
                            Button(type.localizedLabel) { linkedEntityType = type }
                        }
                    }

                    if let linkedEntityType {
                        SelectionMenuRow(
                            title: linkedEntityPickerTitle(for: linkedEntityType),
                            value: linkedEntityDisplayValue(for: linkedEntityType, id: linkedEntityId),
                            isPlaceholder: linkedEntityId == nil
                        ) {
                            Button("Brak powiązania") { linkedEntityId = nil }
                            switch linkedEntityType {
                            case .mission:
                                ForEach(missions) { mission in
                                    Button(mission.title) { linkedEntityId = mission.id }
                                }
                                Divider()
                                Button("Add new mission") { isPresentingAddMission = true }
                            case .incident:
                                ForEach(incidents) { incident in
                                    Button(incident.title) { linkedEntityId = incident.id }
                                }
                                Divider()
                                Button("Add new incident") { isPresentingAddIncident = true }
                            case .place:
                                ForEach(savedPlaces) { place in
                                    Button(place.name) { linkedEntityId = place.id }
                                }
                                Divider()
                                Button("Add new place") { isPresentingAddPlace = true }
                            case .person:
                                ForEach(people) { person in
                                    Button(person.effectiveDisplayName ?? person.email) { linkedEntityId = person.id }
                                }
                            }
                        }
                    }

                    SelectionMenuRow(
                        title: "Incydent",
                        value: incidentTitle(for: selectedIncidentId),
                        isPlaceholder: selectedIncidentId == nil
                    ) {
                        Button("Bez incydentu") { selectedIncidentId = nil }
                        ForEach(incidents) { incident in
                            Button(incident.title) { selectedIncidentId = incident.id }
                        }
                        Divider()
                        Button("Add new incident") { isPresentingAddIncident = true }
                    }

                    SelectionMenuRow(
                        title: "Lokalizacja",
                        value: locationTitle(for: selectedLocationId),
                        isPlaceholder: selectedLocationId == nil
                    ) {
                        Button("Bez lokalizacji") { selectedLocationId = nil }
                        ForEach(locations) { location in
                            Button("\(location.userDisplayName) · \(location.recordedAt.formatted(date: .abbreviated, time: .shortened))") {
                                selectedLocationId = location.id
                            }
                        }
                    }
                }
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
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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

    private func linkedEntityPickerTitle(for type: NoteLinkedEntityType) -> String {
        switch type {
        case .mission:
            return "Mission"
        case .incident:
            return "Incydent"
        case .place:
            return "Miejsce"
        case .person:
            return "Osoba"
        }
    }

    private func linkedEntityDisplayValue(for type: NoteLinkedEntityType, id: UUID?) -> String {
        guard let id else { return "Brak powiązania" }
        switch type {
        case .mission:
            return missions.first(where: { $0.id == id })?.title ?? "Nieznana mission"
        case .incident:
            return incidents.first(where: { $0.id == id })?.title ?? "Nieznany incydent"
        case .place:
            return savedPlaces.first(where: { $0.id == id })?.name ?? "Nieznane miejsce"
        case .person:
            return people.first(where: { $0.id == id })?.effectiveDisplayName
                ?? people.first(where: { $0.id == id })?.email
                ?? "Nieznana osoba"
        }
    }
}

struct NoteEditorFormattingBar: View {
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
                formatButton("Nagłówek", systemImage: "textformat.size.larger", action: onHeading)
                formatButton("Pogrub", systemImage: "bold", action: onBold)
                formatButton("Lista", systemImage: "list.bullet", action: onBullet)
                formatButton("Checklista", systemImage: "checklist", action: onChecklist)
                formatButton("Cytat", systemImage: "text.quote", action: onQuote)
                formatButton("Kod", systemImage: "chevron.left.forwardslash.chevron.right", action: onCode)
                formatButton(
                    isPreviewMode ? "Edytuj" : "Podgląd",
                    systemImage: isPreviewMode ? "pencil" : "eye",
                    action: onTogglePreview
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.thinMaterial)
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
}
