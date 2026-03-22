import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class IncidentStore {
    private let modelContext: ModelContext
    private let repository: IncidentRepository
    private let linkRepository: LinkRepository
    private var cloudSyncEnabled: Bool { AppPreferences.shared.isCloudSyncEnabled }

    var incidents: [Incident] = []
    var isSyncing: Bool = false
    var lastErrorMessage: String?
    var currentSpaceId: UUID?

    init(modelContext: ModelContext, repository: IncidentRepository) {
        self.modelContext = modelContext
        self.repository = repository
        self.linkRepository = LinkRepository(client: SupabaseConfig.client, context: modelContext)
    }

    /// Sets space.
    func setSpace(_ spaceId: UUID?) {
        currentSpaceId = spaceId
        guard let spaceId else {
            incidents = []
            return
        }
        loadLocal(spaceId: spaceId)
    }

    /// Loads local.
    func loadLocal(spaceId: UUID) {
        do {
            incidents = try repository.fetchAllLocal(spaceId: spaceId)
            lastErrorMessage = nil
        } catch {
            incidents = []
            lastErrorMessage = "Nie udało się wczytać lokalnych Incidents: \(error)"
        }
    }

    /// Handles refresh remote.
    func refreshRemote() async {
        guard let spaceId = currentSpaceId else { return }
        guard cloudSyncEnabled else {
            loadLocal(spaceId: spaceId)
            return
        }
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await repository.pullRemoteToLocal(spaceId: spaceId)
            incidents = try repository.fetchAllLocal(spaceId: spaceId)
            lastErrorMessage = nil
        } catch {
            loadLocal(spaceId: spaceId)
            lastErrorMessage = "Nie udało się odświeżyć Incidents z serwera: \(error)"
        }
    }

    /// Handles add incident.
    func addIncident(
        title: String,
        description: String?,
        severity: String,
        status: String,
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
            incidents = try repository.fetchAllLocal(spaceId: spaceId)
            notifyHomeWidgetsDataDidChange()
            await syncPending()
            return incident
        } catch {
            lastErrorMessage = "Nie udało się dodać Incident: \(error)"
            return nil
        }
    }

    /// Updates incident.
    func updateIncident(
        _ incident: Incident,
        title: String? = nil,
        description: String? = nil,
        severity: String? = nil,
        status: String? = nil,
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
            if let iconName {
                incident.iconName = iconName
            }
            if let iconColorHex {
                incident.iconColorHex = iconColorHex
            }
            if let imageData {
                incident.imageData = imageData
            }
            incident.pendingSync = true
            if let spaceId = currentSpaceId {
                try syncRelatedLinks(
                    parentId: incident.id,
                    spaceId: spaceId,
                    desiredChildIds: [relatedMissionId, relatedListId, relatedPlaceId],
                    managedRelatedIds: managedRelatedIds,
                    actor: userId
                )
                incidents = try repository.fetchAllLocal(spaceId: spaceId)
            }
            notifyHomeWidgetsDataDidChange()
            await syncPending()
        } catch {
            lastErrorMessage = "Nie udało się zaktualizować Incident: \(error)"
        }
    }

    /// Deletes incident.
    func deleteIncident(_ incident: Incident, userId: UUID?) async {
        do {
            try repository.softDeleteLocal(incident, updatedBy: userId)
            if let spaceId = currentSpaceId {
                incidents = try repository.fetchAllLocal(spaceId: spaceId)
            }
            notifyHomeWidgetsDataDidChange()
            await syncPending()
        } catch {
            lastErrorMessage = "Nie udało się usunąć Incident: \(error)"
        }
    }

    /// Syncs pending.
    func syncPending() async {
        guard let spaceId = currentSpaceId else { return }
        guard cloudSyncEnabled else {
            loadLocal(spaceId: spaceId)
            lastErrorMessage = nil
            return
        }
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await repository.syncPendingLocal(spaceId: spaceId)
            try await repository.pullRemoteToLocal(spaceId: spaceId)
            incidents = try repository.fetchAllLocal(spaceId: spaceId)
            try modelContext.save()
            notifyHomeWidgetsDataDidChange()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Nie udało się zsynchronizować Incidents: \(error)"
        }
    }

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
