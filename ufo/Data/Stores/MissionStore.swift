import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class MissionStore {
    private let modelContext: ModelContext
    private let repository: MissionRepository
    private var cloudSyncEnabled: Bool { AppPreferences.shared.isCloudSyncEnabled }

    var missions: [Mission] = []
    var currentSpaceId: UUID?
    var isSyncing: Bool = false
    var lastErrorMessage: String?

    init(modelContext: ModelContext, missionRepository: MissionRepository) {
        self.modelContext = modelContext
        self.repository = missionRepository
    }

    /// Sets space.
    func setSpace(_ spaceId: UUID?) {
        currentSpaceId = spaceId
        guard let spaceId else {
            missions = []
            return
        }
        loadLocal(spaceId: spaceId)
    }

    /// Loads local.
    func loadLocal(spaceId: UUID) {
        do {
            missions = try repository.fetchAllLocal(spaceId: spaceId)
            lastErrorMessage = nil
        } catch {
            missions = []
            lastErrorMessage = "Nie udało się wczytać lokalnych Missions: \(error)"
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
            missions = try repository.fetchAllLocal(spaceId: spaceId)
            lastErrorMessage = nil
        } catch {
            loadLocal(spaceId: spaceId)
            lastErrorMessage = "Nie udało się odświeżyć Missions z serwera: \(error)"
        }
    }

    /// Handles add mission.
    func addMission(
        title: String,
        description: String,
        difficulty: Int,
        ownerId: UUID?,
        dueDate: Date?,
        savedPlaceId: UUID?,
        savedPlaceName: String?,
        priority: String,
        isRecurring: Bool,
        iconName: String?,
        iconColorHex: String?,
        imageData: Data?,
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
            missions = try repository.fetchAllLocal(spaceId: spaceId)
            notifyHomeWidgetsDataDidChange()
            await syncPending()
            return mission
        } catch {
            lastErrorMessage = "Nie udało się dodać Mission: \(error)"
            return nil
        }
    }

    /// Updates mission.
    func updateMission(
        _ mission: Mission,
        title: String? = nil,
        description: String? = nil,
        difficulty: Int? = nil,
        ownerId: UUID?? = nil,
        dueDate: Date?? = nil,
        savedPlaceId: UUID?? = nil,
        savedPlaceName: String?? = nil,
        priority: String? = nil,
        isRecurring: Bool? = nil,
        iconName: String? = nil,
        iconColorHex: String? = nil,
        imageData: Data? = nil,
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
            if let iconName {
                mission.iconName = iconName
            }
            if let iconColorHex {
                mission.iconColorHex = iconColorHex
            }
            if let imageData {
                mission.imageData = imageData
            }
            mission.pendingSync = true
            if let spaceId = currentSpaceId {
                missions = try repository.fetchAllLocal(spaceId: spaceId)
            }
            notifyHomeWidgetsDataDidChange()
            await syncPending()
            return true
        } catch {
            lastErrorMessage = "Nie udało się zaktualizować Mission: \(error)"
            return false
        }
    }

    /// Toggles completed.
    func toggleCompleted(_ mission: Mission, userId: UUID?) async {
        _ = await updateMission(mission, isCompleted: !mission.isCompleted, userId: userId)
    }

    /// Deletes mission.
    func deleteMission(_ mission: Mission, userId: UUID?) async {
        do {
            try repository.softDeleteLocal(mission, updatedBy: userId)
            if let spaceId = currentSpaceId {
                missions = try repository.fetchAllLocal(spaceId: spaceId)
            }
            notifyHomeWidgetsDataDidChange()
            await syncPending()
        } catch {
            lastErrorMessage = "Nie udało się usunąć Mission: \(error)"
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
            missions = try repository.fetchAllLocal(spaceId: spaceId)
            try modelContext.save()
            notifyHomeWidgetsDataDidChange()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Nie udało się zsynchronizować Missions: \(error)"
        }
    }
}
