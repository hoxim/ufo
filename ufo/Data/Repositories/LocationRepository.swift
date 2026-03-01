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

    func fetchLocal(spaceId: UUID) throws -> [LocationPing] {
        guard let context else { return [] }
        return try context.fetch(
            FetchDescriptor<LocationPing>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.recordedAt, order: .reverse)]
            )
        )
    }

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

    func pullRemoteToLocal(spaceId: UUID) async throws {
        guard let context else { return }
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

        try context.save()
    }

    func syncPendingLocal(spaceId: UUID) async throws {
        guard let context else { return }
        let pending = try context.fetch(
            FetchDescriptor<LocationPing>(predicate: #Predicate { $0.spaceId == spaceId && $0.pendingSync == true })
        )

        for ping in pending {
            try await upsertRemote(ping)
            ping.pendingSync = false
        }
        try context.save()
    }
}
