import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class LocationStore {
    private let modelContext: ModelContext
    private let repository: LocationRepository

    var pings: [LocationPing] = []
    var currentSpaceId: UUID?
    var isSyncing: Bool = false
    var lastErrorMessage: String?

    init(modelContext: ModelContext, repository: LocationRepository) {
        self.modelContext = modelContext
        self.repository = repository
    }

    /// Sets space.
    func setSpace(_ spaceId: UUID?) {
        currentSpaceId = spaceId
        guard let spaceId else {
            pings = []
            return
        }
        loadLocal(spaceId: spaceId)
    }

    /// Loads local.
    func loadLocal(spaceId: UUID) {
        do {
            pings = try repository.fetchLocal(spaceId: spaceId)
            lastErrorMessage = nil
        } catch {
            pings = []
            lastErrorMessage = "Nie udało się wczytać lokalizacji: \(error)"
        }
    }

    /// Handles refresh remote.
    func refreshRemote() async {
        guard let spaceId = currentSpaceId else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await repository.pullRemoteToLocal(spaceId: spaceId)
            pings = try repository.fetchLocal(spaceId: spaceId)
            lastErrorMessage = nil
        } catch {
            loadLocal(spaceId: spaceId)
            lastErrorMessage = "Nie udało się odświeżyć lokalizacji: \(error)"
        }
    }

    /// Handles add ping.
    func addPing(userId: UUID, userName: String, latitude: Double, longitude: Double, actor: UUID?) async {
        guard let spaceId = currentSpaceId else { return }
        do {
            _ = try repository.createLocal(
                spaceId: spaceId,
                userId: userId,
                userName: userName,
                latitude: latitude,
                longitude: longitude,
                actor: actor
            )
            pings = try repository.fetchLocal(spaceId: spaceId)
            await syncPending()
        } catch {
            lastErrorMessage = "Nie udało się dodać lokalizacji: \(error)"
        }
    }

    /// Syncs pending.
    func syncPending() async {
        guard let spaceId = currentSpaceId else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await repository.syncPendingLocal(spaceId: spaceId)
            try await repository.pullRemoteToLocal(spaceId: spaceId)
            pings = try repository.fetchLocal(spaceId: spaceId)
            try modelContext.save()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Nie udało się zsynchronizować lokalizacji: \(error)"
        }
    }
}
