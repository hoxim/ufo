import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class LocationStore {
    private let modelContext: ModelContext
    private let repository: LocationRepository

    var pings: [LocationPing] = []
    var savedPlaces: [SavedPlace] = []
    var checkIns: [LocationCheckIn] = []
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
        Log.msg("LocationStore.setSpace spaceId=\(spaceId?.uuidString ?? "nil")")
        guard let spaceId else {
            pings = []
            savedPlaces = []
            checkIns = []
            return
        }
        loadLocal(spaceId: spaceId)
    }

    /// Loads local.
    func loadLocal(spaceId: UUID) {
        do {
            pings = try repository.fetchLocal(spaceId: spaceId)
            savedPlaces = try repository.fetchSavedPlacesLocal(spaceId: spaceId)
            checkIns = try repository.fetchCheckInsLocal(spaceId: spaceId)
            lastErrorMessage = nil
            let placeSummary = savedPlaces.map { "\($0.id.uuidString)=\($0.name)" }.joined(separator: ", ")
            Log.msg("LocationStore.loadLocal spaceId=\(spaceId.uuidString) pings=\(pings.count) savedPlaces=\(savedPlaces.count) checkIns=\(checkIns.count) places=[\(placeSummary)]")
        } catch {
            pings = []
            savedPlaces = []
            checkIns = []
            lastErrorMessage = "Nie udało się wczytać lokalizacji: \(error)"
            Log.error("LocationStore.loadLocal failed for spaceId=\(spaceId.uuidString): \(error.localizedDescription)")
        }
    }

    /// Handles refresh remote.
    func refreshRemote() async {
        guard let spaceId = currentSpaceId else { return }
        Log.msg("LocationStore.refreshRemote start spaceId=\(spaceId.uuidString)")
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await repository.pullRemoteToLocal(spaceId: spaceId)
            pings = try repository.fetchLocal(spaceId: spaceId)
            savedPlaces = try repository.fetchSavedPlacesLocal(spaceId: spaceId)
            checkIns = try repository.fetchCheckInsLocal(spaceId: spaceId)
            lastErrorMessage = nil
            Log.msg("LocationStore.refreshRemote success spaceId=\(spaceId.uuidString) savedPlaces=\(savedPlaces.count)")
        } catch {
            loadLocal(spaceId: spaceId)
            lastErrorMessage = "Nie udało się odświeżyć lokalizacji: \(error)"
            Log.error("LocationStore.refreshRemote failed for spaceId=\(spaceId.uuidString): \(error.localizedDescription)")
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
            savedPlaces = try repository.fetchSavedPlacesLocal(spaceId: spaceId)
            checkIns = try repository.fetchCheckInsLocal(spaceId: spaceId)
            await syncPending()
        } catch {
            lastErrorMessage = "Nie udało się dodać lokalizacji: \(error)"
        }
    }

    @discardableResult
    func addSavedPlace(
        name: String,
        description: String?,
        category: String?,
        iconName: String?,
        iconColorHex: String?,
        address: String?,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double,
        actor: UUID?
    ) async -> Bool {
        guard let spaceId = currentSpaceId else {
            lastErrorMessage = "Nie wybrano space do zapisania miejsca."
            Log.error("LocationStore.addSavedPlace aborted because currentSpaceId is nil. name=\(name)")
            return false
        }
        Log.msg("LocationStore.addSavedPlace start spaceId=\(spaceId.uuidString) name=\(name) lat=\(latitude) lon=\(longitude) actor=\(actor?.uuidString ?? "nil")")
        do {
            let created = try repository.createSavedPlaceLocal(
                spaceId: spaceId,
                name: name,
                description: description,
                category: category,
                iconName: iconName,
                iconColorHex: iconColorHex,
                address: address,
                latitude: latitude,
                longitude: longitude,
                radiusMeters: radiusMeters,
                actor: actor
            )
            savedPlaces = try repository.fetchSavedPlacesLocal(spaceId: spaceId)
            lastErrorMessage = nil
            Log.msg("LocationStore.addSavedPlace local save success placeId=\(created.id.uuidString) savedPlaces=\(savedPlaces.count)")
            await syncPending()
            return true
        } catch {
            lastErrorMessage = "Nie udało się dodać miejsca: \(error)"
            Log.error("LocationStore.addSavedPlace failed for spaceId=\(spaceId.uuidString) name=\(name): \(error.localizedDescription)")
            return false
        }
    }

    func addCheckIn(
        userId: UUID,
        userName: String,
        placeId: UUID?,
        placeName: String?,
        latitude: Double,
        longitude: Double,
        note: String?,
        actor: UUID?
    ) async -> LocationCheckIn? {
        guard let spaceId = currentSpaceId else { return nil }
        do {
            let checkIn = try repository.createCheckInLocal(
                spaceId: spaceId,
                userId: userId,
                userName: userName,
                placeId: placeId,
                placeName: placeName,
                latitude: latitude,
                longitude: longitude,
                note: note,
                actor: actor
            )
            checkIns = try repository.fetchCheckInsLocal(spaceId: spaceId)
            await syncPending()
            return checkIn
        } catch {
            lastErrorMessage = "Nie udało się dodać check-in: \(error)"
            return nil
        }
    }

    /// Syncs pending.
    func syncPending() async {
        guard let spaceId = currentSpaceId else { return }
        Log.msg("LocationStore.syncPending start spaceId=\(spaceId.uuidString)")
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await repository.syncPendingLocal(spaceId: spaceId)
            try await repository.pullRemoteToLocal(spaceId: spaceId)
            pings = try repository.fetchLocal(spaceId: spaceId)
            savedPlaces = try repository.fetchSavedPlacesLocal(spaceId: spaceId)
            checkIns = try repository.fetchCheckInsLocal(spaceId: spaceId)
            try modelContext.save()
            lastErrorMessage = nil
            Log.msg("LocationStore.syncPending success spaceId=\(spaceId.uuidString) savedPlaces=\(savedPlaces.count)")
        } catch {
            lastErrorMessage = "Nie udało się zsynchronizować lokalizacji: \(error)"
            Log.error("LocationStore.syncPending failed for spaceId=\(spaceId.uuidString): \(error.localizedDescription)")
        }
    }
}
