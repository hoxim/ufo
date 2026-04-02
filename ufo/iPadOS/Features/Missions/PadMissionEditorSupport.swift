#if os(iOS)

import Foundation
import SwiftData

enum PadMissionEditorSupport {
    static func resolvedPlaces(
        modelContext: ModelContext,
        spaceId: UUID?,
        fallback: [SavedPlace]
    ) -> [SavedPlace] {
        guard let spaceId else { return fallback }
        return (try? modelContext.fetch(
            FetchDescriptor<SavedPlace>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.name, order: .forward)]
            )
        )) ?? fallback
    }

    static func resolvedLists(
        modelContext: ModelContext,
        spaceId: UUID?,
        fallback: [SharedList]
    ) -> [SharedList] {
        guard let spaceId else { return fallback }
        return (try? modelContext.fetch(
            FetchDescriptor<SharedList>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )) ?? fallback
    }

    static func resolvedNotes(
        modelContext: ModelContext,
        spaceId: UUID?,
        fallback: [Note]
    ) -> [Note] {
        guard let spaceId else { return fallback }
        return (try? modelContext.fetch(
            FetchDescriptor<Note>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )) ?? fallback
    }

    static func resolvedIncidents(
        modelContext: ModelContext,
        spaceId: UUID?,
        fallback: [Incident]
    ) -> [Incident] {
        guard let spaceId else { return fallback }
        return (try? modelContext.fetch(
            FetchDescriptor<Incident>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.occurrenceDate, order: .reverse)]
            )
        )) ?? fallback
    }

    static func managedRelatedIds(
        lists: [SharedList],
        notes: [Note],
        incidents: [Incident]
    ) -> [UUID] {
        Array(Set(lists.map(\.id) + notes.map(\.id) + incidents.map(\.id)))
    }
}

#endif
