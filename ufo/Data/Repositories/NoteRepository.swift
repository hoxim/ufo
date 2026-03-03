import Foundation
import SwiftData
import Supabase

@MainActor
final class NoteRepository {
    private let client: SupabaseClient
    private let context: ModelContext?

    init(client: SupabaseClient, context: ModelContext? = nil) {
        self.client = client
        self.context = context
    }

    struct NoteRecord: Codable {
        let id: UUID
        let spaceId: UUID
        let title: String
        let content: String
        let folderId: UUID?
        let attachedLinkURL: String?
        let relatedIncidentId: UUID?
        let relatedLocationLatitude: Double?
        let relatedLocationLongitude: Double?
        let relatedLocationLabel: String?
        let createdBy: UUID?
        let createdAt: Date?
        let updatedAt: Date?
        let version: Int
        let updatedBy: UUID?
        let deletedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id, title, content, version
            case spaceId = "space_id"
            case folderId = "folder_id"
            case attachedLinkURL = "attached_link_url"
            case relatedIncidentId = "related_incident_id"
            case relatedLocationLatitude = "related_location_latitude"
            case relatedLocationLongitude = "related_location_longitude"
            case relatedLocationLabel = "related_location_label"
            case createdBy = "created_by"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case updatedBy = "updated_by"
            case deletedAt = "deleted_at"
        }
    }

    private struct NotePayload: Encodable {
        let id: UUID
        let space_id: UUID
        let title: String
        let content: String
        let folder_id: UUID?
        let attached_link_url: String?
        let related_incident_id: UUID?
        let related_location_latitude: Double?
        let related_location_longitude: Double?
        let related_location_label: String?
        let created_by: UUID?
        let updated_at: Date
        let version: Int
        let updated_by: UUID?
        let deleted_at: Date?
    }

    struct NoteFolderRecord: Codable {
        let id: UUID
        let spaceId: UUID
        let name: String
        let createdBy: UUID?
        let createdAt: Date?
        let updatedAt: Date?
        let version: Int
        let updatedBy: UUID?
        let deletedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id, name, version
            case spaceId = "space_id"
            case createdBy = "created_by"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case updatedBy = "updated_by"
            case deletedAt = "deleted_at"
        }
    }

    private struct NoteFolderPayload: Encodable {
        let id: UUID
        let space_id: UUID
        let name: String
        let created_by: UUID?
        let updated_at: Date
        let version: Int
        let updated_by: UUID?
        let deleted_at: Date?
    }

    /// Reads notes for one space from local SwiftData.
    func fetchAllLocal(spaceId: UUID) throws -> [Note] {
        guard let context else { return [] }
        return try context.fetch(
            FetchDescriptor<Note>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )
    }

    /// Reads folders for one space from local SwiftData.
    func fetchFoldersLocal(spaceId: UUID) throws -> [NoteFolder] {
        guard let context else { return [] }
        return try context.fetch(
            FetchDescriptor<NoteFolder>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )
    }

    /// Creates a local note and marks it for sync.
    func createLocal(
        spaceId: UUID,
        title: String,
        content: String,
        folderId: UUID?,
        attachedLinkURL: String?,
        relatedIncidentId: UUID?,
        relatedLocationLatitude: Double?,
        relatedLocationLongitude: Double?,
        relatedLocationLabel: String?,
        actor: UUID?
    ) throws -> Note {
        guard let context else { throw RepositoryError.missingLocalContext }
        let note = Note(
            spaceId: spaceId,
            title: title,
            content: content,
            folderId: folderId,
            attachedLinkURL: attachedLinkURL,
            relatedIncidentId: relatedIncidentId,
            relatedLocationLatitude: relatedLocationLatitude,
            relatedLocationLongitude: relatedLocationLongitude,
            relatedLocationLabel: relatedLocationLabel,
            createdBy: actor
        )
        note.pendingSync = true
        context.insert(note)
        try context.save()
        return note
    }

    /// Creates local note folder and marks it for sync.
    func createFolderLocal(spaceId: UUID, name: String, actor: UUID?) throws -> NoteFolder {
        guard let context else { throw RepositoryError.missingLocalContext }
        let folder = NoteFolder(spaceId: spaceId, name: name, createdBy: actor)
        folder.pendingSync = true
        context.insert(folder)
        try context.save()
        return folder
    }

    /// Updates a local note and increments version for optimistic sync.
    func markUpdatedLocal(
        _ note: Note,
        title: String,
        content: String,
        folderId: UUID?,
        attachedLinkURL: String?,
        relatedIncidentId: UUID?,
        relatedLocationLatitude: Double?,
        relatedLocationLongitude: Double?,
        relatedLocationLabel: String?,
        actor: UUID?
    ) throws {
        guard context != nil else { throw RepositoryError.missingLocalContext }
        note.title = title
        note.content = content
        note.folderId = folderId
        note.attachedLinkURL = attachedLinkURL
        note.relatedIncidentId = relatedIncidentId
        note.relatedLocationLatitude = relatedLocationLatitude
        note.relatedLocationLongitude = relatedLocationLongitude
        note.relatedLocationLabel = relatedLocationLabel
        note.updatedBy = actor
        note.updatedAt = .now
        note.version += 1
        note.pendingSync = true
        try context?.save()
    }

    /// Soft-deletes a local note.
    func softDeleteLocal(_ note: Note, actor: UUID?) throws {
        guard context != nil else { throw RepositoryError.missingLocalContext }
        note.deletedAt = .now
        note.updatedBy = actor
        note.updatedAt = .now
        note.version += 1
        note.pendingSync = true
        try context?.save()
    }

    /// Pushes one local note to Supabase using upsert.
    func upsertRemote(_ note: Note) async throws {
        let payload = NotePayload(
            id: note.id,
            space_id: note.spaceId,
            title: note.title,
            content: note.content,
            folder_id: note.folderId,
            attached_link_url: note.attachedLinkURL,
            related_incident_id: note.relatedIncidentId,
            related_location_latitude: note.relatedLocationLatitude,
            related_location_longitude: note.relatedLocationLongitude,
            related_location_label: note.relatedLocationLabel,
            created_by: note.createdBy,
            updated_at: note.updatedAt,
            version: note.version,
            updated_by: note.updatedBy,
            deleted_at: note.deletedAt
        )
        try await client.from("notes").upsert(payload).execute()
    }

    /// Pushes local note folder to Supabase using upsert.
    func upsertFolderRemote(_ folder: NoteFolder) async throws {
        let payload = NoteFolderPayload(
            id: folder.id,
            space_id: folder.spaceId,
            name: folder.name,
            created_by: folder.createdBy,
            updated_at: folder.updatedAt,
            version: folder.version,
            updated_by: folder.updatedBy,
            deleted_at: folder.deletedAt
        )
        try await client.from("note_folders").upsert(payload).execute()
    }

    /// Pulls remote notes and merges them into local SwiftData by version.
    func pullRemoteToLocal(spaceId: UUID) async throws {
        guard let context else { return }
        let remote: [NoteRecord] = try await client
            .from("notes")
            .select("*")
            .eq("space_id", value: spaceId)
            .is("deleted_at", value: nil)
            .order("updated_at", ascending: false)
            .execute()
            .value

        for record in remote {
            let local = try context.fetch(
                FetchDescriptor<Note>(predicate: #Predicate { $0.id == record.id })
            ).first
            if let local {
                if local.version <= record.version {
                    local.title = record.title
                    local.content = record.content
                    local.folderId = record.folderId
                    local.attachedLinkURL = record.attachedLinkURL
                    local.relatedIncidentId = record.relatedIncidentId
                    local.relatedLocationLatitude = record.relatedLocationLatitude
                    local.relatedLocationLongitude = record.relatedLocationLongitude
                    local.relatedLocationLabel = record.relatedLocationLabel
                    local.createdBy = record.createdBy
                    local.createdAt = record.createdAt ?? local.createdAt
                    local.updatedAt = record.updatedAt ?? local.updatedAt
                    local.version = record.version
                    local.updatedBy = record.updatedBy
                    local.deletedAt = record.deletedAt
                    local.pendingSync = false
                }
            } else {
                let note = Note(
                    id: record.id,
                    spaceId: record.spaceId,
                    title: record.title,
                    content: record.content,
                    folderId: record.folderId,
                    attachedLinkURL: record.attachedLinkURL,
                    relatedIncidentId: record.relatedIncidentId,
                    relatedLocationLatitude: record.relatedLocationLatitude,
                    relatedLocationLongitude: record.relatedLocationLongitude,
                    relatedLocationLabel: record.relatedLocationLabel,
                    createdBy: record.createdBy
                )
                note.createdAt = record.createdAt ?? .now
                note.updatedAt = record.updatedAt ?? .now
                note.version = record.version
                note.updatedBy = record.updatedBy
                note.deletedAt = record.deletedAt
                note.pendingSync = false
                context.insert(note)
            }
        }

        try context.save()
    }

    /// Pulls remote note folders and merges them into local SwiftData by version.
    func pullFoldersRemoteToLocal(spaceId: UUID) async throws {
        guard let context else { return }
        let remote: [NoteFolderRecord] = try await client
            .from("note_folders")
            .select("*")
            .eq("space_id", value: spaceId)
            .is("deleted_at", value: nil)
            .order("updated_at", ascending: false)
            .execute()
            .value

        for record in remote {
            let local = try context.fetch(
                FetchDescriptor<NoteFolder>(predicate: #Predicate { $0.id == record.id })
            ).first
            if let local {
                if local.version <= record.version {
                    local.name = record.name
                    local.createdBy = record.createdBy
                    local.createdAt = record.createdAt ?? local.createdAt
                    local.updatedAt = record.updatedAt ?? local.updatedAt
                    local.version = record.version
                    local.updatedBy = record.updatedBy
                    local.deletedAt = record.deletedAt
                    local.pendingSync = false
                }
            } else {
                let folder = NoteFolder(
                    id: record.id,
                    spaceId: record.spaceId,
                    name: record.name,
                    createdBy: record.createdBy
                )
                folder.createdAt = record.createdAt ?? .now
                folder.updatedAt = record.updatedAt ?? .now
                folder.version = record.version
                folder.updatedBy = record.updatedBy
                folder.deletedAt = record.deletedAt
                folder.pendingSync = false
                context.insert(folder)
            }
        }

        try context.save()
    }

    /// Syncs all pending local notes for selected space.
    func syncPendingLocal(spaceId: UUID) async throws {
        guard let context else { return }
        let pending = try context.fetch(
            FetchDescriptor<Note>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.pendingSync == true }
            )
        )
        for note in pending {
            try await upsertRemote(note)
            note.pendingSync = false
        }
        try context.save()
    }

    /// Syncs all pending local folders for selected space.
    func syncPendingFoldersLocal(spaceId: UUID) async throws {
        guard let context else { return }
        let pending = try context.fetch(
            FetchDescriptor<NoteFolder>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.pendingSync == true }
            )
        )
        for folder in pending {
            try await upsertFolderRemote(folder)
            folder.pendingSync = false
        }
        try context.save()
    }
}
