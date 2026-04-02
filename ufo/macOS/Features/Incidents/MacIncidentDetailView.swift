#if os(macOS)

import SwiftUI
import SwiftData

struct MacIncidentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthRepository.self) private var authRepo

    let incident: Incident
    var presentationMode: DetailPresentationMode = .modal
    var openedFromLabel: String? = nil
    var onEdit: (() -> Void)? = nil

    @State private var selectedRoute: RelatedContentRoute?
    @State private var isCreatingNote = false
    @State private var isCreatingList = false

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

                HStack {
                    if let iconName = incident.iconName, !iconName.isEmpty {
                        Image(systemName: iconName)
                            .foregroundStyle(Color(hex: incident.iconColorHex ?? "#F59E0B"))
                    }
                    Text(incident.title)
                        .font(.title2.bold())
                }

                if let description = incident.incidentDescription, !description.isEmpty {
                    Text(description)
                        .font(.body)
                }

                HStack(spacing: 10) {
                    Label(
                        IncidentSeverity(rawValue: incident.resolvedSeverity)?.localizedLabel ?? incident.resolvedSeverity.capitalized,
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.caption)

                    Label(
                        IncidentStatus(rawValue: incident.resolvedStatus)?.localizedLabel ?? incident.resolvedStatus.capitalized,
                        systemImage: "clock"
                    )
                    .font(.caption)

                    if let cost = incident.cost {
                        Label(cost.formatted(.currency(code: "PLN")), systemImage: "dollarsign.circle")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)

                RelatedContentSection(title: "Quick Actions") {
                    RelatedContentButton(
                        title: "Create note",
                        subtitle: "Start a note already linked to this incident",
                        systemImage: "square.and.pencil",
                        tint: .blue
                    ) {
                        isCreatingNote = true
                    }

                    RelatedContentButton(
                        title: "Create list",
                        subtitle: "Create a list connected to this incident",
                        systemImage: "checklist",
                        tint: .purple
                    ) {
                        isCreatingList = true
                    }
                }

                if hasRelatedContent {
                    RelatedContentSection(title: "Related") {
                        ForEach(relatedNotes) { note in
                            RelatedContentButton(
                                title: note.title,
                                subtitle: note.previewText.isEmpty ? "Open connected note" : note.previewText,
                                systemImage: "note.text",
                                tint: .blue
                            ) {
                                selectedRoute = .note(note.id)
                            }
                        }

                        ForEach(relatedLists) { list in
                            RelatedContentButton(
                                title: list.name,
                                subtitle: "Open connected list",
                                systemImage: list.iconName ?? "checklist",
                                tint: Color(hex: list.iconColorHex ?? "#6366F1")
                            ) {
                                selectedRoute = .list(list.id)
                            }
                        }

                        if let relatedMission {
                            RelatedContentButton(
                                title: relatedMission.title,
                                subtitle: "Open linked mission",
                                systemImage: relatedMission.iconName ?? "flag",
                                tint: Color(hex: relatedMission.iconColorHex ?? "#F59E0B")
                            ) {
                                selectedRoute = .mission(relatedMission.id)
                            }
                        }

                        if let relatedPlace {
                            RelatedContentButton(
                                title: relatedPlace.name,
                                subtitle: "Open place and navigation options",
                                systemImage: relatedPlace.iconName ?? "mappin.and.ellipse",
                                tint: Color(hex: relatedPlace.iconColorHex ?? "#0F766E")
                            ) {
                                selectedRoute = .place(relatedPlace.id)
                            }
                        }
                    }
                }

                Text(incident.occurrenceDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("incidents.list.title")
        .inlineNavigationTitle()
        .navigationDestination(item: $selectedRoute) { route in
            RelatedContentDestinationView(route: route, originLabel: incident.title)
        }
        .sheet(isPresented: $isCreatingNote) {
            QuickCreateNoteSheet(
                prefillLinkedEntityType: .incident,
                prefillLinkedEntityId: incident.id,
                prefillSavedPlaceId: relatedPlace?.id,
                prefillSelectedIncidentId: incident.id,
                originLabel: incident.title
            )
        }
        .sheet(isPresented: $isCreatingList) {
            QuickCreateLinkedListSheet(
                initialSavedPlaceId: relatedPlace?.id,
                originLabel: incident.title
            ) { listId in
                let repository = LinkRepository(client: SupabaseConfig.client, context: modelContext)
                _ = try? repository.createLocal(
                    thingId: incident.spaceId,
                    parentId: incident.id,
                    childId: listId,
                    actor: authRepo.currentUser?.id
                )
                selectedRoute = .list(listId)
            }
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

    private var relatedNotes: [Note] {
        let spaceId = incident.spaceId
        let incidentId = incident.id
        let linkedIds = linkedChildIds
        let notes = (try? modelContext.fetch(
            FetchDescriptor<Note>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )) ?? []

        return notes.filter { note in
            note.relatedIncidentId == incidentId
                || (note.linkedEntityType == NoteLinkedEntityType.incident.rawValue && note.linkedEntityId == incidentId)
                || linkedIds.contains(note.id)
        }
    }

    private var relatedLists: [SharedList] {
        let spaceId = incident.spaceId
        let linkedIds = linkedChildIds
        let lists = (try? modelContext.fetch(
            FetchDescriptor<SharedList>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )) ?? []

        return lists.filter { linkedIds.contains($0.id) }
    }

    private var relatedMission: Mission? {
        let spaceId = incident.spaceId
        let linkedIds = linkedChildIds
        return (try? modelContext.fetch(
            FetchDescriptor<Mission>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil }
            )
        ))?.first(where: { linkedIds.contains($0.id) })
    }

    private var relatedPlace: SavedPlace? {
        let spaceId = incident.spaceId
        let linkedIds = linkedChildIds
        return (try? modelContext.fetch(
            FetchDescriptor<SavedPlace>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil }
            )
        ))?.first(where: { linkedIds.contains($0.id) })
    }

    private var hasRelatedContent: Bool {
        !relatedNotes.isEmpty || !relatedLists.isEmpty || relatedMission != nil || relatedPlace != nil
    }

    private var linkedChildIds: Set<UUID> {
        let spaceId = incident.spaceId
        let incidentId = incident.id
        let links = (try? modelContext.fetch(
            FetchDescriptor<LinkedThing>(
                predicate: #Predicate { $0.thingId == spaceId && $0.parentId == incidentId && $0.deletedAt == nil }
            )
        )) ?? []
        return Set(links.map(\.childId))
    }
}

#endif
