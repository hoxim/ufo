import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class LocationStore: SpaceScopedStore {
    let modelContext: ModelContext
    private let repository: LocationRepository

    var pings: [LocationPing] = []
    var savedPlaces: [SavedPlace] = []
    var checkIns: [LocationCheckIn] = []
    var currentSpaceId: UUID?
    var isSyncing = false
    var lastErrorMessage: String?

    init(modelContext: ModelContext, repository: LocationRepository) {
        self.modelContext = modelContext
        self.repository = repository
    }

    // MARK: - SpaceScopedStore

    func clearSpaceData() {
        pings = []
        savedPlaces = []
        checkIns = []
    }

    func loadLocal(spaceId: UUID) {
        do {
            pings = try repository.fetchLocal(spaceId: spaceId)
            savedPlaces = try repository.fetchSavedPlacesLocal(spaceId: spaceId)
            checkIns = try repository.fetchCheckInsLocal(spaceId: spaceId)
            lastErrorMessage = nil
        } catch {
            clearSpaceData()
            lastErrorMessage = error.localizedDescription
            Log.error("LocationStore.loadLocal failed for spaceId=\(spaceId.uuidString): \(error.localizedDescription)")
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
            loadLocal(spaceId: spaceId)
            notifyHomeWidgetsDataDidChange()
            await syncPending()
        } catch {
            lastErrorMessage = localizedErrorMessage("locations.error.addPing", error: error)
        }
    }

    @discardableResult
    func addSavedPlace(
        name: String,
        description: String?,
        category: SavedPlaceCategory?,
        iconName: String?,
        iconColorHex: String?,
        address: String?,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double,
        actor: UUID?
    ) async -> SavedPlace? {
        guard let spaceId = currentSpaceId else {
            lastErrorMessage = String(localized: "locations.error.noSelectedSpaceForPlace")
            return nil
        }
        do {
            let created = try repository.createSavedPlaceLocal(
                spaceId: spaceId,
                name: name,
                description: description,
                category: category?.rawValue,
                iconName: iconName,
                iconColorHex: iconColorHex,
                address: address,
                latitude: latitude,
                longitude: longitude,
                radiusMeters: radiusMeters,
                actor: actor
            )
            loadLocal(spaceId: spaceId)
            notifyHomeWidgetsDataDidChange()
            await syncPending()
            return created
        } catch {
            lastErrorMessage = localizedErrorMessage("locations.error.addPlace", error: error)
            return nil
        }
    }

    @discardableResult
    func updateSavedPlace(
        _ place: SavedPlace,
        name: String,
        description: String?,
        category: SavedPlaceCategory?,
        iconName: String?,
        iconColorHex: String?,
        address: String?,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double,
        actor: UUID?
    ) async -> SavedPlace? {
        guard let spaceId = currentSpaceId else {
            lastErrorMessage = String(localized: "locations.error.noSelectedSpaceForPlace")
            return nil
        }
        do {
            try repository.markSavedPlaceUpdatedLocal(
                place,
                name: name,
                description: description,
                category: category?.rawValue,
                iconName: iconName,
                iconColorHex: iconColorHex,
                address: address,
                latitude: latitude,
                longitude: longitude,
                radiusMeters: radiusMeters,
                updatedBy: actor
            )
            loadLocal(spaceId: spaceId)
            notifyHomeWidgetsDataDidChange()
            await syncPending()
            return place
        } catch {
            lastErrorMessage = localizedErrorMessage("locations.error.updatePlace", error: error)
            return nil
        }
    }

    func deleteSavedPlace(_ place: SavedPlace, actor: UUID?) async {
        guard let spaceId = currentSpaceId else {
            lastErrorMessage = String(localized: "locations.error.noSelectedSpaceForPlace")
            return
        }
        do {
            try repository.softDeleteSavedPlaceLocal(place, updatedBy: actor)
            loadLocal(spaceId: spaceId)
            notifyHomeWidgetsDataDidChange()
            await syncPending()
        } catch {
            lastErrorMessage = localizedErrorMessage("locations.error.deletePlace", error: error)
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
            loadLocal(spaceId: spaceId)
            notifyHomeWidgetsDataDidChange()
            await syncPending()
            return checkIn
        } catch {
            lastErrorMessage = localizedErrorMessage("locations.error.addCheckIn", error: error)
            return nil
        }
    }
}
