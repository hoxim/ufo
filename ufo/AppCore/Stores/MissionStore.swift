import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class MissionStore: SpaceScopedStore {
    let modelContext: ModelContext
    private let repository: MissionRepository
    private let linkRepository: LinkRepository

    var missions: [Mission] = []
    var currentSpaceId: UUID?
    var isSyncing = false
    var lastErrorMessage: String?

    init(modelContext: ModelContext, missionRepository: MissionRepository) {
        self.modelContext = modelContext
        self.repository = missionRepository
        self.linkRepository = LinkRepository(client: SupabaseConfig.client, context: modelContext)
    }

    // MARK: - SpaceScopedStore

    func clearSpaceData() {
        missions = []
    }

    func loadLocal(spaceId: UUID) {
        do {
            missions = try repository.fetchAllLocal(spaceId: spaceId)
            lastErrorMessage = nil
        } catch {
            missions = []
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

    func addMission(
        title: String,
        description: String,
        difficulty: Int,
        ownerId: UUID?,
        dueDate: Date?,
        savedPlaceId: UUID?,
        savedPlaceName: String?,
        priority: MissionPriority,
        isRecurring: Bool,
        iconName: String?,
        iconColorHex: String?,
        imageData: Data?,
        relatedListId: UUID?,
        relatedNoteId: UUID?,
        relatedIncidentId: UUID?,
        managedRelatedIds: [UUID],
        userId: UUID?
    ) async -> Mission? {
        guard let spaceId = currentSpaceId else { return nil }
        do {
            let mission = try repository.createLocal(
                spaceId: spaceId,
                title: title,
                description: description,
                difficulty: difficulty,
                ownerId: ownerId,
                dueDate: dueDate,
                savedPlaceId: savedPlaceId,
                savedPlaceName: savedPlaceName,
                priority: priority,
                isRecurring: isRecurring,
                createdBy: userId
            )
            mission.iconName = iconName
            mission.iconColorHex = iconColorHex
            mission.imageData = imageData
            mission.pendingSync = true
            try syncRelatedLinks(
                parentId: mission.id,
                spaceId: spaceId,
                desiredChildIds: [relatedListId, relatedNoteId, relatedIncidentId],
                managedRelatedIds: managedRelatedIds,
                actor: userId
            )
            loadLocal(spaceId: spaceId)
            notifyHomeWidgetsDataDidChange()
            await syncPending()
            return mission
        } catch {
            lastErrorMessage = localizedErrorMessage("missions.error.add", error: error)
            return nil
        }
    }

    func updateMission(
        _ mission: Mission,
        title: String? = nil,
        description: String? = nil,
        difficulty: Int? = nil,
        ownerId: UUID?? = nil,
        dueDate: Date?? = nil,
        savedPlaceId: UUID?? = nil,
        savedPlaceName: String?? = nil,
        priority: MissionPriority? = nil,
        isRecurring: Bool? = nil,
        iconName: String? = nil,
        iconColorHex: String? = nil,
        imageData: Data? = nil,
        relatedListId: UUID? = nil,
        relatedNoteId: UUID? = nil,
        relatedIncidentId: UUID? = nil,
        managedRelatedIds: [UUID] = [],
        isCompleted: Bool? = nil,
        userId: UUID?
    ) async -> Bool {
        do {
            try repository.markUpdatedLocal(
                mission,
                title: title,
                description: description,
                difficulty: difficulty,
                ownerId: ownerId,
                dueDate: dueDate,
                savedPlaceId: savedPlaceId,
                savedPlaceName: savedPlaceName,
                priority: priority,
                isRecurring: isRecurring,
                isCompleted: isCompleted,
                updatedBy: userId
            )
            if let iconName { mission.iconName = iconName }
            if let iconColorHex { mission.iconColorHex = iconColorHex }
            if let imageData { mission.imageData = imageData }
            mission.pendingSync = true
            if let spaceId = currentSpaceId {
                try syncRelatedLinks(
                    parentId: mission.id,
                    spaceId: spaceId,
                    desiredChildIds: [relatedListId, relatedNoteId, relatedIncidentId],
                    managedRelatedIds: managedRelatedIds,
                    actor: userId
                )
                loadLocal(spaceId: spaceId)
            }
            notifyHomeWidgetsDataDidChange()
            await syncPending()
            return true
        } catch {
            lastErrorMessage = localizedErrorMessage("missions.error.update", error: error)
            return false
        }
    }

    func toggleCompleted(_ mission: Mission, userId: UUID?) async {
        _ = await updateMission(mission, isCompleted: !mission.isCompleted, userId: userId)
    }

    func deleteMission(_ mission: Mission, userId: UUID?) async {
        do {
            try repository.softDeleteLocal(mission, updatedBy: userId)
            if let spaceId = currentSpaceId { loadLocal(spaceId: spaceId) }
            notifyHomeWidgetsDataDidChange()
            await syncPending()
        } catch {
            lastErrorMessage = localizedErrorMessage("missions.error.delete", error: error)
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
