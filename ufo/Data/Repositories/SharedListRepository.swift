import Foundation
import SwiftData
import Supabase

@MainActor
final class SharedListRepository {
    private let client: SupabaseClient
    private let context: ModelContext?

    init(client: SupabaseClient, context: ModelContext? = nil) {
        self.client = client
        self.context = context
    }

    struct SharedListRecord: Codable {
        let id: UUID
        let spaceId: UUID
        let name: String
        let type: String
        let createdBy: UUID?
        let createdAt: Date?
        let updatedAt: Date?
        let version: Int
        let updatedBy: UUID?
        let deletedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id, name, type, version
            case spaceId = "space_id"
            case createdBy = "created_by"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case updatedBy = "updated_by"
            case deletedAt = "deleted_at"
        }
    }

    struct SharedListItemRecord: Codable {
        let id: UUID
        let listId: UUID
        let title: String
        let isCompleted: Bool
        let position: Int
        let createdAt: Date?
        let updatedAt: Date?
        let version: Int
        let updatedBy: UUID?
        let deletedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id, title, position, version
            case listId = "list_id"
            case isCompleted = "is_completed"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case updatedBy = "updated_by"
            case deletedAt = "deleted_at"
        }
    }

    private struct SharedListPayload: Encodable {
        let id: UUID
        let space_id: UUID
        let name: String
        let type: String
        let created_by: UUID?
        let updated_at: Date
        let version: Int
        let updated_by: UUID?
        let deleted_at: Date?
    }

    private struct SharedListItemPayload: Encodable {
        let id: UUID
        let list_id: UUID
        let title: String
        let is_completed: Bool
        let position: Int
        let updated_at: Date
        let version: Int
        let updated_by: UUID?
        let deleted_at: Date?
    }

    func fetchListsLocal(spaceId: UUID) throws -> [SharedList] {
        guard let context else { return [] }
        return try context.fetch(
            FetchDescriptor<SharedList>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )
    }

    func fetchItemsLocal(listId: UUID) throws -> [SharedListItem] {
        guard let context else { return [] }
        return try context.fetch(
            FetchDescriptor<SharedListItem>(
                predicate: #Predicate { $0.listId == listId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.position, order: .forward)]
            )
        )
    }

    func createListLocal(spaceId: UUID, name: String, type: SharedListType, actor: UUID?) throws -> SharedList {
        guard let context else { throw RepositoryError.missingLocalContext }
        let list = SharedList(spaceId: spaceId, name: name, type: type.rawValue, createdBy: actor)
        list.pendingSync = true
        context.insert(list)
        try context.save()
        return list
    }

    func createItemLocal(listId: UUID, title: String, position: Int) throws -> SharedListItem {
        guard let context else { throw RepositoryError.missingLocalContext }
        let item = SharedListItem(listId: listId, title: title, position: position)
        item.pendingSync = true
        context.insert(item)
        try context.save()
        return item
    }

    func toggleItemLocal(_ item: SharedListItem, actor: UUID?) throws {
        guard context != nil else { throw RepositoryError.missingLocalContext }
        item.isCompleted.toggle()
        item.updatedBy = actor
        item.updatedAt = .now
        item.version += 1
        item.pendingSync = true
        try context?.save()
    }

    private func upsertListRemote(_ list: SharedList) async throws {
        let payload = SharedListPayload(
            id: list.id,
            space_id: list.spaceId,
            name: list.name,
            type: list.type,
            created_by: list.createdBy,
            updated_at: list.updatedAt,
            version: list.version,
            updated_by: list.updatedBy,
            deleted_at: list.deletedAt
        )
        try await client.from("shared_lists").upsert(payload).execute()
    }

    private func upsertItemRemote(_ item: SharedListItem) async throws {
        let payload = SharedListItemPayload(
            id: item.id,
            list_id: item.listId,
            title: item.title,
            is_completed: item.isCompleted,
            position: item.position,
            updated_at: item.updatedAt,
            version: item.version,
            updated_by: item.updatedBy,
            deleted_at: item.deletedAt
        )
        try await client.from("shared_list_items").upsert(payload).execute()
    }

    func pullRemoteToLocal(spaceId: UUID) async throws {
        guard let context else { return }

        let remoteLists: [SharedListRecord] = try await client
            .from("shared_lists")
            .select("*")
            .eq("space_id", value: spaceId)
            .is("deleted_at", value: nil)
            .order("updated_at", ascending: false)
            .execute()
            .value

        for record in remoteLists {
            let local = try context.fetch(FetchDescriptor<SharedList>(predicate: #Predicate { $0.id == record.id })).first
            if let local {
                if local.version <= record.version {
                    local.name = record.name
                    local.type = record.type
                    local.createdBy = record.createdBy
                    local.createdAt = record.createdAt ?? local.createdAt
                    local.updatedAt = record.updatedAt ?? local.updatedAt
                    local.version = record.version
                    local.updatedBy = record.updatedBy
                    local.deletedAt = record.deletedAt
                    local.pendingSync = false
                }
            } else {
                let list = SharedList(
                    id: record.id,
                    spaceId: record.spaceId,
                    name: record.name,
                    type: record.type,
                    createdBy: record.createdBy
                )
                list.createdAt = record.createdAt ?? .now
                list.updatedAt = record.updatedAt ?? .now
                list.version = record.version
                list.updatedBy = record.updatedBy
                list.deletedAt = record.deletedAt
                list.pendingSync = false
                context.insert(list)
            }
        }

        let listIds = Set(remoteLists.map(\.id))
        if !listIds.isEmpty {
            let allItems: [SharedListItemRecord] = try await client
                .from("shared_list_items")
                .select("*")
                .is("deleted_at", value: nil)
                .order("position", ascending: true)
                .execute()
                .value

            let remoteItems = allItems.filter { listIds.contains($0.listId) }

            for record in remoteItems {
                let local = try context.fetch(FetchDescriptor<SharedListItem>(predicate: #Predicate { $0.id == record.id })).first
                if let local {
                    if local.version <= record.version {
                        local.listId = record.listId
                        local.title = record.title
                        local.isCompleted = record.isCompleted
                        local.position = record.position
                        local.createdAt = record.createdAt ?? local.createdAt
                        local.updatedAt = record.updatedAt ?? local.updatedAt
                        local.version = record.version
                        local.updatedBy = record.updatedBy
                        local.deletedAt = record.deletedAt
                        local.pendingSync = false
                    }
                } else {
                    let item = SharedListItem(
                        id: record.id,
                        listId: record.listId,
                        title: record.title,
                        isCompleted: record.isCompleted,
                        position: record.position
                    )
                    item.createdAt = record.createdAt ?? .now
                    item.updatedAt = record.updatedAt ?? .now
                    item.version = record.version
                    item.updatedBy = record.updatedBy
                    item.deletedAt = record.deletedAt
                    item.pendingSync = false
                    context.insert(item)
                }
            }
        }

        try context.save()
    }

    func syncPendingLocal(spaceId: UUID) async throws {
        guard let context else { return }

        let pendingLists = try context.fetch(
            FetchDescriptor<SharedList>(predicate: #Predicate { $0.spaceId == spaceId && $0.pendingSync == true })
        )
        for list in pendingLists {
            try await upsertListRemote(list)
            list.pendingSync = false
        }

        let spaceLists = try fetchListsLocal(spaceId: spaceId)
        let listIds = Set(spaceLists.map(\.id))
        if !listIds.isEmpty {
            let pendingItems = try context.fetch(
                FetchDescriptor<SharedListItem>(predicate: #Predicate { $0.pendingSync == true })
            ).filter { listIds.contains($0.listId) }
            for item in pendingItems {
                try await upsertItemRemote(item)
                item.pendingSync = false
            }
        }

        try context.save()
    }
}
