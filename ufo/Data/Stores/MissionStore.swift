import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class MissionStore {
    private let modelContext: ModelContext
    private let repository: MissionRepository

    var missions: [Mission] = []
    var currentSpaceId: UUID?
    var isSyncing: Bool = false
    var lastErrorMessage: String?

    init(modelContext: ModelContext, missionRepository: MissionRepository) {
        self.modelContext = modelContext
        self.repository = missionRepository
    }

    func setSpace(_ spaceId: UUID?) {
        currentSpaceId = spaceId
        guard let spaceId else {
            missions = []
            return
        }
        loadLocal(spaceId: spaceId)
    }

    func loadLocal(spaceId: UUID) {
        do {
            missions = try repository.fetchAllLocal(spaceId: spaceId)
            lastErrorMessage = nil
        } catch {
            missions = []
            lastErrorMessage = "Nie udało się wczytać lokalnych Missions: \(error)"
        }
    }

    func refreshRemote() async {
        guard let spaceId = currentSpaceId else { return }
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

    func addMission(title: String, description: String, difficulty: Int, iconName: String?, imageData: Data?, userId: UUID?) async {
        guard let spaceId = currentSpaceId else { return }
        do {
            let mission = try repository.createLocal(
                spaceId: spaceId,
                title: title,
                description: description,
                difficulty: difficulty,
                createdBy: userId
            )
            mission.iconName = iconName
            mission.imageData = imageData
            mission.pendingSync = true
            missions = try repository.fetchAllLocal(spaceId: spaceId)
            await syncPending()
        } catch {
            lastErrorMessage = "Nie udało się dodać Mission: \(error)"
        }
    }

    func updateMission(
        _ mission: Mission,
        title: String? = nil,
        description: String? = nil,
        difficulty: Int? = nil,
        iconName: String? = nil,
        imageData: Data? = nil,
        isCompleted: Bool? = nil,
        userId: UUID?
    ) async {
        do {
            try repository.markUpdatedLocal(
                mission,
                title: title,
                description: description,
                difficulty: difficulty,
                isCompleted: isCompleted,
                updatedBy: userId
            )
            if let iconName {
                mission.iconName = iconName
            }
            if let imageData {
                mission.imageData = imageData
            }
            mission.pendingSync = true
            if let spaceId = currentSpaceId {
                missions = try repository.fetchAllLocal(spaceId: spaceId)
            }
            await syncPending()
        } catch {
            lastErrorMessage = "Nie udało się zaktualizować Mission: \(error)"
        }
    }

    func toggleCompleted(_ mission: Mission, userId: UUID?) async {
        await updateMission(mission, isCompleted: !mission.isCompleted, userId: userId)
    }

    func deleteMission(_ mission: Mission, userId: UUID?) async {
        do {
            try repository.softDeleteLocal(mission, updatedBy: userId)
            if let spaceId = currentSpaceId {
                missions = try repository.fetchAllLocal(spaceId: spaceId)
            }
            await syncPending()
        } catch {
            lastErrorMessage = "Nie udało się usunąć Mission: \(error)"
        }
    }

    func syncPending() async {
        guard let spaceId = currentSpaceId else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await repository.syncPendingLocal(spaceId: spaceId)
            try await repository.pullRemoteToLocal(spaceId: spaceId)
            missions = try repository.fetchAllLocal(spaceId: spaceId)
            try modelContext.save()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Nie udało się zsynchronizować Missions: \(error)"
        }
    }
}
