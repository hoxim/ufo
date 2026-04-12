import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class IncidentStore: SpaceScopedStore {
    let modelContext: ModelContext
    private let repository: IncidentRepository
    private let linkRepository: LinkRepository

    var incidents: [Incident] = []
    var currentSpaceId: UUID?
    var isSyncing = false
    var lastErrorMessage: String?

    init(modelContext: ModelContext, repository: IncidentRepository) {
        self.modelContext = modelContext
        self.repository = repository
        self.linkRepository = LinkRepository(client: SupabaseConfig.client, context: modelContext)
    }

    // MARK: - SpaceScopedStore

    func clearSpaceData() {
        incidents = []
    }

    func loadLocal(spaceId: UUID) {
        do {
            incidents = try repository.fetchAllLocal(spaceId: spaceId)
            lastErrorMessage = nil
        } catch {
            incidents = []
            lastErrorMessage = error.localizedDescription
        }
    }

    func pullRemoteData(spaceId: UUID) async throws {
        try await repository.pullRemoteToLocal(spaceId: spaceId)
    }

    func syncPendingData(spaceId: UUID) async throws {
        try await repository.syncPendingLocal(spaceId: spaceId)
    }

    func afterSync() {
        notifyHomeWidgetsDataDidChange()
    }

    // MARK: - CRUD

    func addIncident(
        title: String,
        description: String?,
        severity: IncidentSeverity,
        status: IncidentStatus,
        assigneeId: UUID?,
        cost: Double?,
        occurrenceDate: Date,
        iconName: String?,
        iconColorHex: String?,
        imageData: Data?,
        relatedMissionId: UUID?,
        relatedListId: UUID?,
        relatedPlaceId: UUID?,
        managedRelatedIds: [UUID],
        userId: UUID?
    ) async -> Incident? {
        guard let spaceId = currentSpaceId else { return nil }
        do {
            let incident = try repository.createLocal(
                spaceId: spaceId,
                title: title,
                description: description,
                severity: severity,
                status: status,
                assigneeId: assigneeId,
                cost: cost,
                occurrenceDate: occurrenceDate,
                createdBy: userId
            )
            incident.iconName = iconName
            incident.iconColorHex = iconColorHex
            incident.imageData = imageData
            incident.pendingSync = true
            try syncRelatedLinks(
                parentId: incident.id,
                spaceId: spaceId,
                desiredChildIds: [relatedMissionId, relatedListId, relatedPlaceId],
                managedRelatedIds: managedRelatedIds,
                actor: userId
            )
            loadLocal(spaceId: spaceId)
            notifyHomeWidgetsDataDidChange()
            await syncPending()
            return incident
        } catch {
            lastErrorMessage = localizedErrorMessage("incidents.error.add", error: error)
            return nil
        }
    }

    func updateIncident(
        _ incident: Incident,
        title: String? = nil,
        description: String? = nil,
        severity: IncidentSeverity? = nil,
        status: IncidentStatus? = nil,
        assigneeId: UUID?? = nil,
        cost: Double?? = nil,
        occurrenceDate: Date? = nil,
        iconName: String? = nil,
        iconColorHex: String? = nil,
        imageData: Data? = nil,
        relatedMissionId: UUID? = nil,
        relatedListId: UUID? = nil,
        relatedPlaceId: UUID? = nil,
        managedRelatedIds: [UUID] = [],
        userId: UUID?
    ) async {
        do {
            try repository.markUpdatedLocal(
                incident,
                title: title,
                description: description,
                severity: severity,
                status: status,
                assigneeId: assigneeId,
                cost: cost,
                occurrenceDate: occurrenceDate,
                updatedBy: userId
            )
            if let iconName { incident.iconName = iconName }
            if let iconColorHex { incident.iconColorHex = iconColorHex }
            if let imageData { incident.imageData = imageData }
            incident.pendingSync = true
            if let spaceId = currentSpaceId {
                try syncRelatedLinks(
                    parentId: incident.id,
                    spaceId: spaceId,
                    desiredChildIds: [relatedMissionId, relatedListId, relatedPlaceId],
                    managedRelatedIds: managedRelatedIds,
                    actor: userId
                )
                loadLocal(spaceId: spaceId)
            }
            notifyHomeWidgetsDataDidChange()
            await syncPending()
        } catch {
            lastErrorMessage = localizedErrorMessage("incidents.error.update", error: error)
        }
    }

    func deleteIncident(_ incident: Incident, userId: UUID?) async {
        do {
            try repository.softDeleteLocal(incident, updatedBy: userId)
            if let spaceId = currentSpaceId { loadLocal(spaceId: spaceId) }
            notifyHomeWidgetsDataDidChange()
            await syncPending()
        } catch {
            lastErrorMessage = localizedErrorMessage("incidents.error.delete", error: error)
        }
    }

    // MARK: - Private

    private func syncRelatedLinks(
        parentId: UUID,
        spaceId: UUID,
        desiredChildIds: [UUID?],
        managedRelatedIds: [UUID],
        actor: UUID?
    ) throws {
        let desired = Set(desiredChildIds.compactMap { $0 })
        let managed = Set(managedRelatedIds)
        let existing = try linkRepository.fetchAllLocal(scopeId: spaceId).filter { $0.parentId == parentId }

        for link in existing where managed.contains(link.childId) && !desired.contains(link.childId) {
            try linkRepository.softDeleteLocal(link, actor: actor)
        }

        let existingChildIds = Set(existing.filter { $0.deletedAt == nil }.map(\.childId))
        for childId in desired where !existingChildIds.contains(childId) {
            _ = try linkRepository.createLocal(
                thingId: spaceId,
                parentId: parentId,
                childId: childId,
                actor: actor
            )
        }
    }
}
