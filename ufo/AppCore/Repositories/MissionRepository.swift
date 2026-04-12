import Foundation
import SwiftData
import Supabase

@MainActor
final class MissionRepository {

    private let client: SupabaseClient
    private let context: ModelContext?

    init(client: SupabaseClient, context: ModelContext? = nil) {
        self.client = client
        self.context = context
    }

    // MARK: - Remote DTO

    struct MissionRecord: Codable {
        let id: UUID
        let spaceId: UUID
        let title: String
        let description: String
        let difficulty: Int
        let isCompleted: Bool
        let ownerId: UUID?
        let dueDate: Date?
        let savedPlaceId: UUID?
        let savedPlaceName: String?
        let priority: String
        let isRecurring: Bool
        let createdBy: UUID?
        let createdAt: Date?
        let updatedAt: Date?
        let lastUpdatedAt: Date?
        let version: Int
        let updatedBy: UUID?
        let deletedAt: Date?
        let iconName: String?
        let iconColorHex: String?
        let visibilityMode: String?

        enum CodingKeys: String, CodingKey {
            case id, title, description, difficulty, version
            case spaceId = "space_id"
            case isCompleted = "is_completed"
            case ownerId = "owner_id"
            case dueDate = "due_date"
            case savedPlaceId = "saved_place_id"
            case savedPlaceName = "saved_place_name"
            case priority
            case isRecurring = "is_recurring"
            case createdBy = "created_by"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case lastUpdatedAt = "last_updated_at"
            case updatedBy = "updated_by"
            case deletedAt = "deleted_at"
            case iconName = "icon_name"
            case iconColorHex = "icon_color_hex"
            case visibilityMode = "visibility_mode"
        }
    }

    private struct MissionUpsertPayload: Encodable {
        let id: UUID
        let space_id: UUID
        let title: String
        let description: String
        let difficulty: Int
        let is_completed: Bool
        let owner_id: UUID?
        let due_date: Date?
        let saved_place_id: UUID?
        let saved_place_name: String?
        let priority: String
        let is_recurring: Bool
        let version: Int
        let created_by: UUID?
        let last_updated_at: Date
        let updated_at: Date
        let updated_by: UUID?
        let deleted_at: Date?
        let icon_name: String?
        let icon_color_hex: String?
        let visibility_mode: String
    }

    // MARK: - Backward compatibility (old API used in MissionStore)

    /// Fetches mission.
    func fetchMission(id: UUID) async throws -> MissionRecord? {
        let mission: MissionRecord? = try await client
            .from("missions")
            .select("*")
            .eq("id", value: id)
            .single()
            .execute()
            .value
        return mission
    }

    /// Updates mission.
    func updateMission(_ mission: Mission) async throws {
        let payload = MissionUpsertPayload(
            id: mission.id,
            space_id: mission.spaceId,
            title: mission.title,
            description: mission.missionDescription,
            difficulty: mission.difficulty,
            is_completed: mission.isCompleted,
            owner_id: mission.ownerId,
            due_date: mission.dueDate,
            saved_place_id: mission.savedPlaceId,
            saved_place_name: mission.savedPlaceName,
            priority: mission.priority.rawValue,
            is_recurring: mission.isRecurring,
            version: mission.version,
            created_by: mission.createdBy,
            last_updated_at: mission.lastUpdatedAt,
            updated_at: mission.updatedAt,
            updated_by: mission.updatedBy,
            deleted_at: mission.deletedAt,
            icon_name: mission.iconName,
            icon_color_hex: mission.iconColorHex,
            visibility_mode: mission.visibilityMode.rawValue
        )

        try await client
            .from("missions")
            .upsert(payload)
            .execute()
    }

    // MARK: - CRUD + helpers (local-first)

    /// Fetches all remote.
    private func fetchAllRemote(spaceId: UUID) async throws -> [MissionRecord] {
        try await client
            .from("missions")
            .select("*")
            .eq("space_id", value: spaceId)
            .is("deleted_at", value: nil)
            .order("last_updated_at", ascending: false)
            .execute()
            .value
    }

    /// Fetches by id remote.
    func fetchByIdRemote(id: UUID) async throws -> MissionRecord? {
        try await client
            .from("missions")
            .select("*")
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    /// Fetches all local.
    func fetchAllLocal(spaceId: UUID) throws -> [Mission] {
        guard let context else { return [] }
        let descriptor = FetchDescriptor<Mission>(
            predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.lastUpdatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// Fetches local.
    func fetchLocal(id: UUID) throws -> Mission? {
        guard let context else { return nil }
        let descriptor = FetchDescriptor<Mission>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    /// Creates local.
    func createLocal(
        spaceId: UUID,
        title: String,
        description: String,
        difficulty: Int,
        ownerId: UUID?,
        dueDate: Date?,
        savedPlaceId: UUID?,
        savedPlaceName: String?,
        priority: MissionPriority,
        isRecurring: Bool,
        visibilityMode: SpaceContentVisibilityMode = .everyone,
        createdBy: UUID?
    ) throws -> Mission {
        guard let context else { throw RepositoryError.missingLocalContext }
        let mission = Mission(
            spaceId: spaceId,
            title: title,
            missionDescription: description,
            difficulty: difficulty,
            ownerId: ownerId,
            dueDate: dueDate,
            savedPlaceId: savedPlaceId,
            savedPlaceName: savedPlaceName,
            priority: priority,
            isRecurring: isRecurring,
            visibilityMode: visibilityMode,
            createdBy: createdBy
        )
        mission.pendingSync = true
        context.insert(mission)
        try context.save()
        return mission
    }

    /// Handles mark updated local.
    func markUpdatedLocal(
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
        visibilityMode: SpaceContentVisibilityMode? = nil,
        isCompleted: Bool? = nil,
        updatedBy: UUID?
    ) throws {
        guard context != nil else { throw RepositoryError.missingLocalContext }
        if let title { mission.title = title }
        if let description { mission.missionDescription = description }
        if let difficulty { mission.difficulty = difficulty }
        if let ownerId { mission.ownerId = ownerId }
        if let dueDate { mission.dueDate = dueDate }
        if let savedPlaceId { mission.savedPlaceId = savedPlaceId }
        if let savedPlaceName { mission.savedPlaceName = savedPlaceName }
        if let priority { mission.priority = priority }
        if let isRecurring { mission.isRecurring = isRecurring }
        if let visibilityMode { mission.visibilityMode = visibilityMode }
        if let isCompleted { mission.isCompleted = isCompleted }
        mission.updatedBy = updatedBy
        mission.version += 1
        mission.lastUpdatedAt = .now
        mission.updatedAt = .now
        mission.pendingSync = true
        try context?.save()
    }

    /// Handles soft delete local.
    func softDeleteLocal(_ mission: Mission, updatedBy: UUID?) throws {
        guard context != nil else { throw RepositoryError.missingLocalContext }
        mission.deletedAt = .now
        mission.updatedBy = updatedBy
        mission.version += 1
        mission.lastUpdatedAt = .now
        mission.updatedAt = .now
        mission.pendingSync = true
        try context?.save()
    }

    /// Handles upsert remote.
    func upsertRemote(_ mission: Mission) async throws {
        try await updateMission(mission)
    }

    /// Handles pull remote to local.
    func pullRemoteToLocal(spaceId: UUID) async throws {
        guard let context else { return }
        let remote = try await fetchAllRemote(spaceId: spaceId)
        for record in remote {
            let local = try fetchLocal(id: record.id)

            if let local {
                if local.version <= record.version {
                    local.title = record.title
                    local.missionDescription = record.description
                    local.difficulty = record.difficulty
                    local.isCompleted = record.isCompleted
                    local.ownerId = record.ownerId
                    local.dueDate = record.dueDate
                    local.savedPlaceId = record.savedPlaceId
                    local.savedPlaceName = record.savedPlaceName
                    local.priority = MissionPriority(rawValue: record.priority) ?? .medium
                    local.isRecurring = record.isRecurring
                    local.createdBy = record.createdBy
                    local.createdAt = record.createdAt ?? local.createdAt
                    local.updatedAt = record.updatedAt ?? local.updatedAt
                    local.lastUpdatedAt = record.lastUpdatedAt ?? local.lastUpdatedAt
                    local.updatedBy = record.updatedBy
                    local.version = record.version
                    local.deletedAt = record.deletedAt
                    local.iconName = record.iconName
                    local.iconColorHex = record.iconColorHex
                    local.visibilityMode = SpaceContentVisibilityMode(rawValue: record.visibilityMode ?? "") ?? .everyone
                    local.pendingSync = false
                }
            } else {
                let mission = Mission(
                    id: record.id,
                    spaceId: record.spaceId,
                    title: record.title,
                    missionDescription: record.description,
                    difficulty: record.difficulty,
                    ownerId: record.ownerId,
                    dueDate: record.dueDate,
                    savedPlaceId: record.savedPlaceId,
                    savedPlaceName: record.savedPlaceName,
                    priority: MissionPriority(rawValue: record.priority) ?? .medium,
                    isRecurring: record.isRecurring,
                    visibilityMode: SpaceContentVisibilityMode(rawValue: record.visibilityMode ?? "") ?? .everyone,
                    iconName: record.iconName,
                    iconColorHex: record.iconColorHex,
                    createdBy: record.createdBy
                )
                mission.isCompleted = record.isCompleted
                mission.createdAt = record.createdAt ?? .now
                mission.updatedAt = record.updatedAt ?? .now
                mission.lastUpdatedAt = record.lastUpdatedAt ?? .now
                mission.updatedBy = record.updatedBy
                mission.version = record.version
                mission.deletedAt = record.deletedAt
                mission.pendingSync = false
                context.insert(mission)
            }
        }
        try context.save()
    }

    /// Syncs pending local.
    func syncPendingLocal(spaceId: UUID) async throws {
        guard let context else { return }
        let pending = try context.fetch(
            FetchDescriptor<Mission>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.pendingSync == true }
            )
        )

        for mission in pending {
            try await upsertRemote(mission)
            mission.pendingSync = false
        }
        try context.save()
    }
}

enum RepositoryError: Error {
    case missingLocalContext
}
