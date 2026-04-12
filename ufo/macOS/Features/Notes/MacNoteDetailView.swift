#if os(macOS)

//
//  MacNoteDetailView.swift
//  ufo
//
//  Created by Marcin Ryzko on 17/03/2026.
//

import SwiftUI
import SwiftData

struct MacNoteDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let note: Note
    var presentationMode: DetailPresentationMode = .modal
    var openedFromLabel: String? = nil
    var onEdit: (() -> Void)? = nil

    @State private var selectedRoute: RelatedContentRoute?
    
    var body: some View {
        Group {
            if presentationMode == .modal {
                NavigationStack {
                    detailContent
                }
            } else {
                detailContent
            }
        }
    }

    private var detailContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let openedFromLabel {
                    OpenedFromBadge(title: openedFromLabel)
                }

                if !note.content.isEmpty {
                    Text(note.renderedContent)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if let url = note.attachedLinkURL, !url.isEmpty, let validURL = URL(string: url) {
                    Link(destination: validURL) {
                        Label(url, systemImage: "link")
                            .lineLimit(1)
                    }
                }

                if hasRelatedContent {
                    RelatedContentSection(title: "Related") {
                        if let savedPlace = relatedPlace {
                            RelatedContentButton(
                                title: savedPlace.name,
                                subtitle: "Open place and navigation options",
                                systemImage: savedPlace.iconName ?? "mappin.and.ellipse",
                                tint: Color(hex: savedPlace.iconColorHex ?? "#0F766E")
                            ) {
                                selectedRoute = .place(savedPlace.id)
                            }
                        }

                        if let incident = relatedIncident {
                            RelatedContentButton(
                                title: incident.title,
                                subtitle: incident.severity.localizedLabel,
                                systemImage: incident.iconName ?? "exclamationmark.triangle",
                                tint: Color(hex: incident.iconColorHex ?? "#F59E0B")
                            ) {
                                selectedRoute = .incident(incident.id)
                            }
                        }

                        if let linkedRoute, let linkedEntityTitle {
                            RelatedContentButton(
                                title: linkedEntityTitle,
                                subtitle: linkedEntitySubtitle,
                                systemImage: linkedEntitySystemImage,
                                tint: linkedEntityTint
                            ) {
                                selectedRoute = linkedRoute
                            }
                        }
                    }
                } else if note.relatedLocationLatitude != nil && note.relatedLocationLongitude != nil {
                    Label(note.relatedLocationLabel ?? String(localized: "notes.view.badge.location"), systemImage: "location")
                        .font(.caption)
                }
                
                Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(note.title)
        .inlineNavigationTitle()
        .navigationDestination(item: $selectedRoute) { route in
            RelatedContentDestinationView(route: route, originLabel: note.title)
        }
        .toolbar {
            if presentationMode == .modal {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            if let onEdit {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onEdit()
                    } label: {
                        Label("common.edit", systemImage: "pencil")
                    }
                }
            }
        }
    }

    private var relatedPlace: SavedPlace? {
        guard let savedPlaceId = note.savedPlaceId else { return nil }
        return try? modelContext.fetch(
            FetchDescriptor<SavedPlace>(
                predicate: #Predicate { $0.id == savedPlaceId && $0.deletedAt == nil }
            )
        ).first
    }

    private var relatedIncident: Incident? {
        guard let relatedIncidentId = note.relatedIncidentId else { return nil }
        return try? modelContext.fetch(
            FetchDescriptor<Incident>(
                predicate: #Predicate { $0.id == relatedIncidentId && $0.deletedAt == nil }
            )
        ).first
    }

    private var linkedRoute: RelatedContentRoute? {
        guard let linkedEntityType = note.linkedEntityType, let linkedEntityId = note.linkedEntityId else { return nil }
        switch NoteLinkedEntityType(rawValue: linkedEntityType) {
        case .mission:
            return .mission(linkedEntityId)
        case .incident:
            return .incident(linkedEntityId)
        case .place:
            return .place(linkedEntityId)
        default:
            return nil
        }
    }

    private var linkedEntityTitle: String? {
        switch linkedRoute {
        case .mission(let id):
            return resolveMission(id)?.title ?? "Linked mission"
        case .incident(let id):
            return resolveIncident(id)?.title ?? "Linked incident"
        case .place(let id):
            return resolvePlace(id)?.name ?? "Linked place"
        default:
            return nil
        }
    }

    private var linkedEntitySubtitle: String {
        switch linkedRoute {
        case .mission:
            return "Open linked mission"
        case .incident:
            return "Open linked incident"
        case .place:
            return "Open linked place"
        default:
            return "Open linked item"
        }
    }

    private var linkedEntitySystemImage: String {
        switch linkedRoute {
        case .mission:
            return "flag"
        case .incident:
            return "exclamationmark.triangle"
        case .place:
            return "mappin.and.ellipse"
        default:
            return "link"
        }
    }

    private var linkedEntityTint: Color {
        switch linkedRoute {
        case .mission:
            return .orange
        case .incident:
            return .red
        case .place:
            return .teal
        default:
            return .accentColor
        }
    }

    private var hasRelatedContent: Bool {
        relatedPlace != nil || relatedIncident != nil || linkedRoute != nil
    }

    private func resolveMission(_ id: UUID) -> Mission? {
        try? modelContext.fetch(
            FetchDescriptor<Mission>(
                predicate: #Predicate { $0.id == id && $0.deletedAt == nil }
            )
        ).first
    }

    private func resolveIncident(_ id: UUID) -> Incident? {
        try? modelContext.fetch(
            FetchDescriptor<Incident>(
                predicate: #Predicate { $0.id == id && $0.deletedAt == nil }
            )
        ).first
    }

    private func resolvePlace(_ id: UUID) -> SavedPlace? {
        try? modelContext.fetch(
            FetchDescriptor<SavedPlace>(
                predicate: #Predicate { $0.id == id && $0.deletedAt == nil }
            )
        ).first
    }
}

#Preview("Note Detail") {
    let preview = MacNotesPreviewFactory.make()

    return MacNoteDetailView(
        note: preview.note,
        onEdit: {}
    )
    .modelContainer(preview.container)
}

#endif
