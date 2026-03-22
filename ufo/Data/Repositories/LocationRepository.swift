import Foundation
import SwiftData
import Supabase

@MainActor
final class LocationRepository {
    private let client: SupabaseClient
    private let context: ModelContext?

    init(client: SupabaseClient, context: ModelContext? = nil) {
        self.client = client
        self.context = context
    }

    struct LocationRecord: Codable {
        let id: UUID
        let spaceId: UUID
        let userId: UUID
        let userDisplayName: String
        let latitude: Double
        let longitude: Double
        let recordedAt: Date
        let createdAt: Date?
        let updatedAt: Date?
        let version: Int
        let updatedBy: UUID?
        let deletedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id, latitude, longitude, version
            case spaceId = "space_id"
            case userId = "user_id"
            case userDisplayName = "user_display_name"
            case recordedAt = "recorded_at"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case updatedBy = "updated_by"
            case deletedAt = "deleted_at"
        }
    }

    struct SavedPlaceRecord: Codable {
        let id: UUID
        let spaceId: UUID
        let name: String
        let placeDescription: String?
        let category: String?
        let iconName: String?
        let iconColorHex: String?
        let address: String?
        let latitude: Double
        let longitude: Double
        let radiusMeters: Double
        let createdBy: UUID?
        let createdAt: Date?
        let updatedAt: Date?
        let version: Int
        let updatedBy: UUID?
        let deletedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id, name, category, latitude, longitude, version
            case placeDescription = "description"
            case iconName = "icon_name"
            case iconColorHex = "icon_color_hex"
            case address
            case spaceId = "space_id"
            case radiusMeters = "radius_meters"
            case createdBy = "created_by"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case updatedBy = "updated_by"
            case deletedAt = "deleted_at"
        }
    }

    struct LocationCheckInRecord: Codable {
        let id: UUID
        let spaceId: UUID
        let userId: UUID
        let userDisplayName: String
        let placeId: UUID?
        let placeName: String?
        let latitude: Double
        let longitude: Double
        let note: String?
        let checkedInAt: Date
        let createdAt: Date?
        let updatedAt: Date?
        let version: Int
        let updatedBy: UUID?
        let deletedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id, latitude, longitude, note, version
            case spaceId = "space_id"
            case userId = "user_id"
            case userDisplayName = "user_display_name"
            case placeId = "place_id"
            case placeName = "place_name"
            case checkedInAt = "checked_in_at"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case updatedBy = "updated_by"
            case deletedAt = "deleted_at"
        }
    }

    private struct LocationPayload: Encodable {
        let id: UUID
        let space_id: UUID
        let user_id: UUID
        let user_display_name: String
        let latitude: Double
        let longitude: Double
        let recorded_at: Date
        let updated_at: Date
        let version: Int
        let updated_by: UUID?
        let deleted_at: Date?
    }

    private struct SavedPlacePayload: Encodable {
        let id: UUID
        let space_id: UUID
        let name: String
        let description: String?
        let category: String?
        let icon_name: String?
        let icon_color_hex: String?
        let address: String?
        let latitude: Double
        let longitude: Double
        let radius_meters: Double
        let created_by: UUID?
        let updated_at: Date
        let version: Int
        let updated_by: UUID?
        let deleted_at: Date?
    }

    private struct LocationCheckInPayload: Encodable {
        let id: UUID
        let space_id: UUID
        let user_id: UUID
        let user_display_name: String
        let place_id: UUID?
        let place_name: String?
        let latitude: Double
        let longitude: Double
        let note: String?
        let checked_in_at: Date
        let updated_at: Date
        let version: Int
        let updated_by: UUID?
        let deleted_at: Date?
    }

    /// Fetches local.
    func fetchLocal(spaceId: UUID) throws -> [LocationPing] {
        guard let context else { return [] }
        return try context.fetch(
            FetchDescriptor<LocationPing>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.recordedAt, order: .reverse)]
            )
        )
    }

    func fetchSavedPlacesLocal(spaceId: UUID) throws -> [SavedPlace] {
        guard let context else { return [] }
        let places = try context.fetch(
            FetchDescriptor<SavedPlace>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.name, order: .forward)]
            )
        )
        let summary = places.map { "\($0.id.uuidString)=\($0.name)(pending=\($0.pendingSync))" }.joined(separator: ", ")
        Log.msg("LocationRepository.fetchSavedPlacesLocal spaceId=\(spaceId.uuidString) count=\(places.count) places=[\(summary)]")
        return places
    }

    func fetchCheckInsLocal(spaceId: UUID) throws -> [LocationCheckIn] {
        guard let context else { return [] }
        return try context.fetch(
            FetchDescriptor<LocationCheckIn>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.checkedInAt, order: .reverse)]
            )
        )
    }

    /// Creates local.
    func createLocal(spaceId: UUID, userId: UUID, userName: String, latitude: Double, longitude: Double, actor: UUID?) throws -> LocationPing {
        guard let context else { throw RepositoryError.missingLocalContext }
        let ping = LocationPing(
            spaceId: spaceId,
            userId: userId,
            userDisplayName: userName,
            latitude: latitude,
            longitude: longitude,
            recordedAt: .now
        )
        ping.updatedBy = actor
        ping.pendingSync = true
        context.insert(ping)
        try context.save()
        return ping
    }

    func createSavedPlaceLocal(
        spaceId: UUID,
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
    ) throws -> SavedPlace {
        guard let context else { throw RepositoryError.missingLocalContext }
        let place = SavedPlace(
            spaceId: spaceId,
            name: name,
            placeDescription: description,
            category: category,
            iconName: iconName,
            iconColorHex: iconColorHex,
            address: address,
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters,
            createdBy: actor
        )
        place.updatedBy = actor
        place.pendingSync = true
        context.insert(place)
        try context.save()
        Log.msg("LocationRepository.createSavedPlaceLocal saved placeId=\(place.id.uuidString) spaceId=\(spaceId.uuidString) name=\(name) pendingSync=\(place.pendingSync)")
        return place
    }

    func markSavedPlaceUpdatedLocal(
        _ place: SavedPlace,
        name: String,
        description: String?,
        category: String?,
        iconName: String?,
        iconColorHex: String?,
        address: String?,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double,
        updatedBy: UUID?
    ) throws {
        guard context != nil else { throw RepositoryError.missingLocalContext }
        place.name = name
        place.placeDescription = description
        place.category = category
        place.iconName = iconName
        place.iconColorHex = iconColorHex
        place.address = address
        place.latitude = latitude
        place.longitude = longitude
        place.radiusMeters = radiusMeters
        place.updatedBy = updatedBy
        place.version += 1
        place.updatedAt = .now
        place.pendingSync = true
        try context?.save()
    }

    func softDeleteSavedPlaceLocal(_ place: SavedPlace, updatedBy: UUID?) throws {
        guard context != nil else { throw RepositoryError.missingLocalContext }
        place.deletedAt = .now
        place.updatedBy = updatedBy
        place.version += 1
        place.updatedAt = .now
        place.pendingSync = true
        try context?.save()
    }

    func createCheckInLocal(
        spaceId: UUID,
        userId: UUID,
        userName: String,
        placeId: UUID?,
        placeName: String?,
        latitude: Double,
        longitude: Double,
        note: String?,
        actor: UUID?
    ) throws -> LocationCheckIn {
        guard let context else { throw RepositoryError.missingLocalContext }
        let checkIn = LocationCheckIn(
            spaceId: spaceId,
            userId: userId,
            userDisplayName: userName,
            placeId: placeId,
            placeName: placeName,
            latitude: latitude,
            longitude: longitude,
            note: note
        )
        checkIn.updatedBy = actor
        checkIn.pendingSync = true
        context.insert(checkIn)
        try context.save()
        return checkIn
    }

    /// Handles upsert remote.
    private func upsertRemote(_ ping: LocationPing) async throws {
        let payload = LocationPayload(
            id: ping.id,
            space_id: ping.spaceId,
            user_id: ping.userId,
            user_display_name: ping.userDisplayName,
            latitude: ping.latitude,
            longitude: ping.longitude,
            recorded_at: ping.recordedAt,
            updated_at: ping.updatedAt,
            version: ping.version,
            updated_by: ping.updatedBy,
            deleted_at: ping.deletedAt
        )
        try await client.from("location_pings").upsert(payload).execute()
    }

    private func upsertRemote(_ place: SavedPlace) async throws {
        let payload = SavedPlacePayload(
            id: place.id,
            space_id: place.spaceId,
            name: place.name,
            description: place.placeDescription,
            category: place.category,
            icon_name: place.iconName,
            icon_color_hex: place.iconColorHex,
            address: place.address,
            latitude: place.latitude,
            longitude: place.longitude,
            radius_meters: place.radiusMeters,
            created_by: place.createdBy,
            updated_at: place.updatedAt,
            version: place.version,
            updated_by: place.updatedBy,
            deleted_at: place.deletedAt
        )
        Log.msg("LocationRepository.upsertRemote(savedPlace) placeId=\(place.id.uuidString) spaceId=\(place.spaceId.uuidString) name=\(place.name) version=\(place.version)")
        try await client.from("saved_places").upsert(payload).execute()
    }

    private func upsertRemote(_ checkIn: LocationCheckIn) async throws {
        let payload = LocationCheckInPayload(
            id: checkIn.id,
            space_id: checkIn.spaceId,
            user_id: checkIn.userId,
            user_display_name: checkIn.userDisplayName,
            place_id: checkIn.placeId,
            place_name: checkIn.placeName,
            latitude: checkIn.latitude,
            longitude: checkIn.longitude,
            note: checkIn.note,
            checked_in_at: checkIn.checkedInAt,
            updated_at: checkIn.updatedAt,
            version: checkIn.version,
            updated_by: checkIn.updatedBy,
            deleted_at: checkIn.deletedAt
        )
        try await client.from("location_check_ins").upsert(payload).execute()
    }

    /// Handles pull remote to local.
    func pullRemoteToLocal(spaceId: UUID) async throws {
        guard let context else { return }
        Log.msg("LocationRepository.pullRemoteToLocal start spaceId=\(spaceId.uuidString)")
        let remote: [LocationRecord] = try await client
            .from("location_pings")
            .select("*")
            .eq("space_id", value: spaceId)
            .is("deleted_at", value: nil)
            .order("recorded_at", ascending: false)
            .limit(200)
            .execute()
            .value

        for record in remote {
            let local = try context.fetch(FetchDescriptor<LocationPing>(predicate: #Predicate { $0.id == record.id })).first
            if let local {
                if local.version <= record.version {
                    local.userId = record.userId
                    local.userDisplayName = record.userDisplayName
                    local.latitude = record.latitude
                    local.longitude = record.longitude
                    local.recordedAt = record.recordedAt
                    local.createdAt = record.createdAt ?? local.createdAt
                    local.updatedAt = record.updatedAt ?? local.updatedAt
                    local.version = record.version
                    local.updatedBy = record.updatedBy
                    local.deletedAt = record.deletedAt
                    local.pendingSync = false
                }
            } else {
                let ping = LocationPing(
                    id: record.id,
                    spaceId: record.spaceId,
                    userId: record.userId,
                    userDisplayName: record.userDisplayName,
                    latitude: record.latitude,
                    longitude: record.longitude,
                    recordedAt: record.recordedAt
                )
                ping.createdAt = record.createdAt ?? .now
                ping.updatedAt = record.updatedAt ?? .now
                ping.version = record.version
                ping.updatedBy = record.updatedBy
                ping.deletedAt = record.deletedAt
                ping.pendingSync = false
                context.insert(ping)
            }
        }

        let remotePlaces: [SavedPlaceRecord] = try await client
            .from("saved_places")
            .select("*")
            .eq("space_id", value: spaceId)
            .is("deleted_at", value: nil)
            .order("name", ascending: true)
            .execute()
            .value
        let remotePlaceSummary = remotePlaces.map { "\($0.id.uuidString)=\($0.name)" }.joined(separator: ", ")
        Log.msg("LocationRepository.pullRemoteToLocal fetched remote saved_places spaceId=\(spaceId.uuidString) count=\(remotePlaces.count) places=[\(remotePlaceSummary)]")

        for record in remotePlaces {
            let local = try context.fetch(FetchDescriptor<SavedPlace>(predicate: #Predicate { $0.id == record.id })).first
            if let local {
                if local.version <= record.version {
                    local.name = record.name
                    local.placeDescription = record.placeDescription
                    local.category = record.category
                    local.iconName = record.iconName
                    local.iconColorHex = record.iconColorHex
                    local.address = record.address
                    local.latitude = record.latitude
                    local.longitude = record.longitude
                    local.radiusMeters = record.radiusMeters
                    local.createdBy = record.createdBy
                    local.createdAt = record.createdAt ?? local.createdAt
                    local.updatedAt = record.updatedAt ?? local.updatedAt
                    local.version = record.version
                    local.updatedBy = record.updatedBy
                    local.deletedAt = record.deletedAt
                    local.pendingSync = false
                }
            } else {
                let place = SavedPlace(
                    id: record.id,
                    spaceId: record.spaceId,
                    name: record.name,
                    placeDescription: record.placeDescription,
                    category: record.category,
                    iconName: record.iconName,
                    iconColorHex: record.iconColorHex,
                    address: record.address,
                    latitude: record.latitude,
                    longitude: record.longitude,
                    radiusMeters: record.radiusMeters,
                    createdBy: record.createdBy
                )
                place.createdAt = record.createdAt ?? .now
                place.updatedAt = record.updatedAt ?? .now
                place.version = record.version
                place.updatedBy = record.updatedBy
                place.deletedAt = record.deletedAt
                place.pendingSync = false
                context.insert(place)
            }
        }

        let remoteCheckIns: [LocationCheckInRecord] = try await client
            .from("location_check_ins")
            .select("*")
            .eq("space_id", value: spaceId)
            .is("deleted_at", value: nil)
            .order("checked_in_at", ascending: false)
            .limit(100)
            .execute()
            .value

        for record in remoteCheckIns {
            let local = try context.fetch(FetchDescriptor<LocationCheckIn>(predicate: #Predicate { $0.id == record.id })).first
            if let local {
                if local.version <= record.version {
                    local.userId = record.userId
                    local.userDisplayName = record.userDisplayName
                    local.placeId = record.placeId
                    local.placeName = record.placeName
                    local.latitude = record.latitude
                    local.longitude = record.longitude
                    local.note = record.note
                    local.checkedInAt = record.checkedInAt
                    local.createdAt = record.createdAt ?? local.createdAt
                    local.updatedAt = record.updatedAt ?? local.updatedAt
                    local.version = record.version
                    local.updatedBy = record.updatedBy
                    local.deletedAt = record.deletedAt
                    local.pendingSync = false
                }
            } else {
                let checkIn = LocationCheckIn(
                    id: record.id,
                    spaceId: record.spaceId,
                    userId: record.userId,
                    userDisplayName: record.userDisplayName,
                    placeId: record.placeId,
                    placeName: record.placeName,
                    latitude: record.latitude,
                    longitude: record.longitude,
                    note: record.note,
                    checkedInAt: record.checkedInAt
                )
                checkIn.createdAt = record.createdAt ?? .now
                checkIn.updatedAt = record.updatedAt ?? .now
                checkIn.version = record.version
                checkIn.updatedBy = record.updatedBy
                checkIn.deletedAt = record.deletedAt
                checkIn.pendingSync = false
                context.insert(checkIn)
            }
        }

        try context.save()
        Log.msg("LocationRepository.pullRemoteToLocal success spaceId=\(spaceId.uuidString)")
    }

    /// Syncs pending local.
    func syncPendingLocal(spaceId: UUID) async throws {
        guard let context else { return }
        Log.msg("LocationRepository.syncPendingLocal start spaceId=\(spaceId.uuidString)")
        let pending = try context.fetch(
            FetchDescriptor<LocationPing>(predicate: #Predicate { $0.spaceId == spaceId && $0.pendingSync == true })
        )

        for ping in pending {
            try await upsertRemote(ping)
            ping.pendingSync = false
        }

        let pendingPlaces = try context.fetch(
            FetchDescriptor<SavedPlace>(predicate: #Predicate { $0.spaceId == spaceId && $0.pendingSync == true })
        )
        Log.msg("LocationRepository.syncPendingLocal pending saved_places spaceId=\(spaceId.uuidString) count=\(pendingPlaces.count)")
        for place in pendingPlaces {
            try await upsertRemote(place)
            place.pendingSync = false
        }

        let pendingCheckIns = try context.fetch(
            FetchDescriptor<LocationCheckIn>(predicate: #Predicate { $0.spaceId == spaceId && $0.pendingSync == true })
        )
        for checkIn in pendingCheckIns {
            try await upsertRemote(checkIn)
            checkIn.pendingSync = false
        }
        try context.save()
        Log.msg("LocationRepository.syncPendingLocal success spaceId=\(spaceId.uuidString)")
    }
}
