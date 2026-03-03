import Foundation
import SwiftData
import Supabase

@MainActor
final class IncidentRepository {

    private let client: SupabaseClient
    private let context: ModelContext?

    init(client: SupabaseClient, context: ModelContext? = nil) {
        self.client = client
        self.context = context
    }

    struct IncidentRecord: Codable {
        let id: UUID
        let spaceId: UUID
        let createdBy: UUID?
        let title: String
        let description: String?
        let occurrenceDate: Date
        let createdAt: Date?
        let lastUpdatedAt: Date?
        let updatedAt: Date?
        let version: Int
        let updatedBy: UUID?
        let deletedAt: Date?
        let iconName: String?
        let iconColorHex: String?

        enum CodingKeys: String, CodingKey {
            case id, title, description, version
            case spaceId = "space_id"
            case createdBy = "created_by"
            case occurrenceDate = "occurrence_date"
            case createdAt = "created_at"
            case lastUpdatedAt = "last_updated_at"
            case updatedAt = "updated_at"
            case updatedBy = "updated_by"
            case deletedAt = "deleted_at"
            case iconName = "icon_name"
            case iconColorHex = "icon_color_hex"
        }
    }

    private struct IncidentPayload: Encodable {
        let id: UUID
        let space_id: UUID
        let created_by: UUID?
        let title: String
        let description: String?
        let occurrence_date: Date
        let version: Int
        let last_updated_at: Date
        let updated_at: Date
        let updated_by: UUID?
        let deleted_at: Date?
        let icon_name: String?
        let icon_color_hex: String?
    }

    /// Fetches all remote.
    private func fetchAllRemote(spaceId: UUID) async throws -> [IncidentRecord] {
        try await client
            .from("incidents")
            .select("*")
            .eq("space_id", value: spaceId)
            .is("deleted_at", value: nil)
            .order("last_updated_at", ascending: false)
            .execute()
            .value
    }

    /// Fetches by id remote.
    func fetchByIdRemote(id: UUID) async throws -> IncidentRecord? {
        try await client
            .from("incidents")
            .select("*")
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    /// Fetches all local.
    func fetchAllLocal(spaceId: UUID) throws -> [Incident] {
        guard let context else { return [] }
        return try context.fetch(
            FetchDescriptor<Incident>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.lastUpdatedAt, order: .reverse)]
            )
        )
    }

    /// Creates local.
    func createLocal(spaceId: UUID, title: String, description: String?, occurrenceDate: Date, createdBy: UUID?) throws -> Incident {
        guard let context else { throw RepositoryError.missingLocalContext }
        let incident = Incident(
            spaceId: spaceId,
            title: title,
            incidentDescription: description,
            occurrenceDate: occurrenceDate,
            createdBy: createdBy
        )
        incident.pendingSync = true
        context.insert(incident)
        try context.save()
        return incident
    }

    /// Handles mark updated local.
    func markUpdatedLocal(_ incident: Incident, title: String? = nil, description: String? = nil, occurrenceDate: Date? = nil, updatedBy: UUID?) throws {
        guard context != nil else { throw RepositoryError.missingLocalContext }
        if let title { incident.title = title }
        if let description { incident.incidentDescription = description }
        if let occurrenceDate { incident.occurrenceDate = occurrenceDate }
        incident.updatedBy = updatedBy
        incident.version += 1
        incident.lastUpdatedAt = .now
        incident.updatedAt = .now
        incident.pendingSync = true
        try context?.save()
    }

    /// Handles soft delete local.
    func softDeleteLocal(_ incident: Incident, updatedBy: UUID?) throws {
        guard context != nil else { throw RepositoryError.missingLocalContext }
        incident.deletedAt = .now
        incident.updatedBy = updatedBy
        incident.version += 1
        incident.lastUpdatedAt = .now
        incident.updatedAt = .now
        incident.pendingSync = true
        try context?.save()
    }

    /// Handles upsert remote.
    func upsertRemote(_ incident: Incident) async throws {
        let payload = IncidentPayload(
            id: incident.id,
            space_id: incident.spaceId,
            created_by: incident.createdBy,
            title: incident.title,
            description: incident.incidentDescription,
            occurrence_date: incident.occurrenceDate,
            version: incident.version,
            last_updated_at: incident.lastUpdatedAt,
            updated_at: incident.updatedAt,
            updated_by: incident.updatedBy,
            deleted_at: incident.deletedAt,
            icon_name: incident.iconName,
            icon_color_hex: incident.iconColorHex
        )

        try await client
            .from("incidents")
            .upsert(payload)
            .execute()
    }

    /// Handles pull remote to local.
    func pullRemoteToLocal(spaceId: UUID) async throws {
        guard let context else { return }
        let remote = try await fetchAllRemote(spaceId: spaceId)

        for record in remote {
            let local = try context.fetch(
                FetchDescriptor<Incident>(
                    predicate: #Predicate { $0.id == record.id }
                )
            ).first

            if let local {
                if local.version <= record.version {
                    local.title = record.title
                    local.incidentDescription = record.description
                    local.occurrenceDate = record.occurrenceDate
                    local.createdBy = record.createdBy
                    local.createdAt = record.createdAt ?? local.createdAt
                    local.lastUpdatedAt = record.lastUpdatedAt ?? local.lastUpdatedAt
                    local.updatedAt = record.updatedAt ?? local.updatedAt
                    local.updatedBy = record.updatedBy
                    local.version = record.version
                    local.deletedAt = record.deletedAt
                    local.iconName = record.iconName
                    local.iconColorHex = record.iconColorHex
                    local.pendingSync = false
                }
            } else {
                let incident = Incident(
                    id: record.id,
                    spaceId: record.spaceId,
                    title: record.title,
                    incidentDescription: record.description,
                    occurrenceDate: record.occurrenceDate,
                    iconName: record.iconName,
                    iconColorHex: record.iconColorHex,
                    createdBy: record.createdBy
                )
                incident.createdAt = record.createdAt ?? .now
                incident.lastUpdatedAt = record.lastUpdatedAt ?? .now
                incident.updatedAt = record.updatedAt ?? .now
                incident.updatedBy = record.updatedBy
                incident.version = record.version
                incident.deletedAt = record.deletedAt
                incident.pendingSync = false
                context.insert(incident)
            }
        }

        try context.save()
    }

    /// Syncs pending local.
    func syncPendingLocal(spaceId: UUID) async throws {
        guard let context else { return }
        let pending = try context.fetch(
            FetchDescriptor<Incident>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.pendingSync == true }
            )
        )

        for incident in pending {
            try await upsertRemote(incident)
            incident.pendingSync = false
        }
        try context.save()
    }
}
