#if os(macOS)

import SwiftUI
import SwiftData

struct MacMissionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthRepository.self) private var authRepo

    let mission: Mission
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
            VStack(alignment: .leading, spacing: 18) {
                if let openedFromLabel {
                    OpenedFromBadge(title: openedFromLabel)
                }

                HStack(spacing: 10) {
                    if let iconName = mission.iconName, !iconName.isEmpty {
                        Image(systemName: iconName)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color(hex: mission.iconColorHex ?? "#F59E0B"))
                    }
                    Text(mission.title)
                        .font(.title2.bold())
                }

                HStack(spacing: 10) {
                    Image(systemName: mission.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(mission.isCompleted ? .green : .gray)
                    Text(mission.isCompleted ? "Completed" : "Open")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    Label(mission.priority.localizedLabel, systemImage: "flag")
                        .font(.caption)
                    if mission.isRecurring {
                        Label("Recurring", systemImage: "repeat")
                            .font(.caption)
                    }
                    if let dueDate = mission.dueDate {
                        Label(dueDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .font(.caption)
                    }
                    if let savedPlaceName = mission.savedPlaceName, !savedPlaceName.isEmpty {
                        Label(savedPlaceName, systemImage: "mappin.and.ellipse")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)

                if !mission.missionDescription.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("missions.editor.field.description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(mission.missionDescription)
                            .font(.body)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("missions.editor.field.difficulty")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        ForEach(0..<mission.difficulty, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                        }
                    }
                }

                RelatedContentSection(title: "Quick Actions") {
                    RelatedContentButton(
                        title: "Create note",
                        subtitle: "Start a note already linked to this mission",
                        systemImage: "square.and.pencil",
                        tint: .blue
                    ) {
                        isCreatingNote = true
                    }

                    RelatedContentButton(
                        title: "Create list",
                        subtitle: "Create a shopping or task list for this mission",
                        systemImage: "checklist",
                        tint: .purple
                    ) {
                        isCreatingList = true
                    }
                }

                if hasRelatedContent {
                    RelatedContentSection(title: "Related") {
                        if let savedPlace = relatedPlace {
                            RelatedContentButton(
                                title: savedPlace.name,
                                subtitle: "Open place and start navigation",
                                systemImage: savedPlace.iconName ?? "mappin.and.ellipse",
                                tint: Color(hex: savedPlace.iconColorHex ?? "#0F766E")
                            ) {
                                selectedRoute = .place(savedPlace.id)
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

                        ForEach(relatedIncidents) { incident in
                            RelatedContentButton(
                                title: incident.title,
                                subtitle: incident.severity.localizedLabel,
                                systemImage: incident.iconName ?? "exclamationmark.triangle",
                                tint: Color(hex: incident.iconColorHex ?? "#F59E0B")
                            ) {
                                selectedRoute = .incident(incident.id)
                            }
                        }
                    }
                }

                missionImageView

                Text(mission.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Mission")
        .inlineNavigationTitle()
        .navigationDestination(item: $selectedRoute) { route in
            RelatedContentDestinationView(route: route, originLabel: mission.title)
        }
        .sheet(isPresented: $isCreatingNote) {
            QuickCreateNoteSheet(
                prefillLinkedEntityType: .mission,
                prefillLinkedEntityId: mission.id,
                prefillSavedPlaceId: mission.savedPlaceId,
                prefillSelectedIncidentId: relatedIncidents.first?.id,
                originLabel: mission.title
            )
        }
        .sheet(isPresented: $isCreatingList) {
            QuickCreateLinkedListSheet(
                initialSavedPlaceId: mission.savedPlaceId,
                originLabel: mission.title
            ) { listId in
                let repository = LinkRepository(client: SupabaseConfig.client, context: modelContext)
                _ = try? repository.createLocal(
                    thingId: mission.spaceId,
                    parentId: mission.id,
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

    private var relatedPlace: SavedPlace? {
        guard let savedPlaceId = mission.savedPlaceId else { return nil }
        return try? modelContext.fetch(
            FetchDescriptor<SavedPlace>(
                predicate: #Predicate { $0.id == savedPlaceId && $0.deletedAt == nil }
            )
        ).first
    }

    private var relatedNotes: [Note] {
        let spaceId = mission.spaceId
        let missionId = mission.id
        let linkedIds = linkedChildIds
        let notes = (try? modelContext.fetch(
            FetchDescriptor<Note>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )) ?? []

        return notes.filter { note in
            (note.linkedEntityType == NoteLinkedEntityType.mission.rawValue && note.linkedEntityId == missionId)
                || linkedIds.contains(note.id)
        }
    }

    private var relatedLists: [SharedList] {
        let spaceId = mission.spaceId
        let linkedIds = linkedChildIds
        let lists = (try? modelContext.fetch(
            FetchDescriptor<SharedList>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )) ?? []

        return lists.filter { linkedIds.contains($0.id) }
    }

    private var relatedIncidents: [Incident] {
        let spaceId = mission.spaceId
        let linkedIds = linkedChildIds
        let incidents = (try? modelContext.fetch(
            FetchDescriptor<Incident>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.occurrenceDate, order: .reverse)]
            )
        )) ?? []

        return incidents.filter { linkedIds.contains($0.id) }
    }

    private var hasRelatedContent: Bool {
        relatedPlace != nil || !relatedLists.isEmpty || !relatedNotes.isEmpty || !relatedIncidents.isEmpty
    }

    private var linkedChildIds: Set<UUID> {
        let spaceId = mission.spaceId
        let missionId = mission.id
        let links = (try? modelContext.fetch(
            FetchDescriptor<LinkedThing>(
                predicate: #Predicate { $0.thingId == spaceId && $0.parentId == missionId && $0.deletedAt == nil }
            )
        )) ?? []
        return Set(links.map(\.childId))
    }

    @ViewBuilder
    private var missionImageView: some View {
        if let imageData = mission.imageData {
            PlatformImageView(data: imageData)
        }
    }
}

#Preview("Mission Detail") {
    let mission = Mission(
        spaceId: UUID(),
        title: "Prepare emergency bag",
        missionDescription: "Check batteries, flashlight and first aid kit.",
        difficulty: 3
    )
    mission.iconName = "backpack"
    mission.iconColorHex = "#F59E0B"

    return MacMissionDetailView(
        mission: mission,
        onEdit: {}
    )
}

#endif
