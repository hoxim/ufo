import Foundation
import SwiftData
import Supabase

@MainActor
final class LinkRepository {

    private let client: SupabaseClient
    private let context: ModelContext?

    init(client: SupabaseClient, context: ModelContext? = nil) {
        self.client = client
        self.context = context
    }

    private struct LinkPayload: Encodable {
        let id: UUID
        let thing_id: UUID?
        let parent_id: UUID
        let child_id: UUID
        let created_at: Date
        let updated_at: Date
        let version: Int
        let updated_by: UUID?
        let deleted_at: Date?
    }

    struct LinkRecord: Codable {
        let id: UUID
        let thingId: UUID?
        let parentId: UUID
        let childId: UUID
        let createdAt: Date?
        let updatedAt: Date?
        let version: Int
        let updatedBy: UUID?
        let deletedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id, version
            case thingId = "thing_id"
            case parentId = "parent_id"
            case childId = "child_id"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case updatedBy = "updated_by"
            case deletedAt = "deleted_at"
        }
    }

    /// Fetches all local.
    func fetchAllLocal(scopeId: UUID) throws -> [LinkedThing] {
        guard let context else { return [] }
        return try context.fetch(
            FetchDescriptor<LinkedThing>(
                predicate: #Predicate { $0.thingId == scopeId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )
    }

    /// Creates local.
    func createLocal(thingId: UUID?, parentId: UUID, childId: UUID, actor: UUID?) throws -> LinkedThing {
        guard let context else { throw RepositoryError.missingLocalContext }
        let link = LinkedThing(
            thingId: thingId,
            parentId: parentId,
            childId: childId,
            updatedBy: actor
        )
        link.pendingSync = true
        context.insert(link)
        try context.save()
        return link
    }

    /// Handles soft delete local.
    func softDeleteLocal(_ link: LinkedThing, actor: UUID?) throws {
        guard context != nil else { throw RepositoryError.missingLocalContext }
        link.deletedAt = .now
        link.updatedBy = actor
        link.version += 1
        link.updatedAt = .now
        link.pendingSync = true
        try context?.save()
    }

    /// Handles upsert remote.
    func upsertRemote(_ link: LinkedThing) async throws {
        let payload = LinkPayload(
            id: link.id,
            thing_id: link.thingId,
            parent_id: link.parentId,
            child_id: link.childId,
            created_at: link.createdAt,
            updated_at: link.updatedAt,
            version: link.version,
            updated_by: link.updatedBy,
            deleted_at: link.deletedAt
        )

        try await client
            .from("links")
            .upsert(payload)
            .execute()
    }

    /// Fetches all remote.
    private func fetchAllRemote(scopeId: UUID) async throws -> [LinkRecord] {
        try await client
            .from("links")
            .select("*")
            .eq("thing_id", value: scopeId)
            .is("deleted_at", value: nil)
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    /// Handles pull remote to local.
    func pullRemoteToLocal(scopeId: UUID) async throws {
        guard let context else { return }
        let remote = try await fetchAllRemote(scopeId: scopeId)

        for record in remote {
            let existing = try context.fetch(
                FetchDescriptor<LinkedThing>(
                    predicate: #Predicate { $0.id == record.id }
                )
            ).first

            if let existing {
                if existing.version <= record.version {
                    existing.thingId = record.thingId
                    existing.parentId = record.parentId
                    existing.childId = record.childId
                    existing.createdAt = record.createdAt ?? existing.createdAt
                    existing.updatedAt = record.updatedAt ?? existing.updatedAt
                    existing.version = record.version
                    existing.updatedBy = record.updatedBy
                    existing.deletedAt = record.deletedAt
                    existing.pendingSync = false
                }
            } else {
                let link = LinkedThing(
                    id: record.id,
                    thingId: record.thingId,
                    parentId: record.parentId,
                    childId: record.childId,
                    createdAt: record.createdAt ?? .now,
                    updatedAt: record.updatedAt ?? .now,
                    version: record.version,
                    updatedBy: record.updatedBy,
                    deletedAt: record.deletedAt,
                    pendingSync: false
                )
                context.insert(link)
            }
        }

        try context.save()
    }

    /// Syncs pending local.
    func syncPendingLocal(scopeId: UUID) async throws {
        guard let context else { return }
        let pending = try context.fetch(
            FetchDescriptor<LinkedThing>(
                predicate: #Predicate { $0.thingId == scopeId && $0.pendingSync == true }
            )
        )

        for link in pending {
            try await upsertRemote(link)
            link.pendingSync = false
        }
        try context.save()
    }
}
