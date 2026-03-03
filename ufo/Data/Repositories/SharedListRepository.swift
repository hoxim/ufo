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
        let iconName: String?
        let iconColorHex: String?
        let createdBy: UUID?
        let createdAt: Date?
        let updatedAt: Date?
        let version: Int
        let updatedBy: UUID?
        let deletedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id, name, type, version
            case spaceId = "space_id"
            case iconName = "icon_name"
            case iconColorHex = "icon_color_hex"
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
        let icon_name: String?
        let icon_color_hex: String?
        let created_by: UUID?
        let updated_at: Date
        let version: Int
        let updated_by: UUID?
        let deleted_at: Date?
    }

    private struct SharedListPayloadLegacy: Encodable {
        let id: UUID
        let space_id: UUID
        let name: String
        let type: String
        let icon_name: String?
        let created_by: UUID?
        let updated_at: Date
        let version: Int
        let updated_by: UUID?
        let deleted_at: Date?
    }

    private struct SharedListPayloadMinimal: Encodable {
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

    /// Fetches lists local.
    func fetchListsLocal(spaceId: UUID) throws -> [SharedList] {
        guard let context else { return [] }
        return try context.fetch(
            FetchDescriptor<SharedList>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )
    }

    /// Fetches items local.
    func fetchItemsLocal(listId: UUID) throws -> [SharedListItem] {
        guard let context else { return [] }
        return try context.fetch(
            FetchDescriptor<SharedListItem>(
                predicate: #Predicate { $0.listId == listId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.position, order: .forward)]
            )
        )
    }

    /// Creates list local.
    func createListLocal(spaceId: UUID, name: String, type: SharedListType, iconName: String?, iconColorHex: String?, actor: UUID?) throws -> SharedList {
        guard let context else { throw RepositoryError.missingLocalContext }
        let list = SharedList(
            spaceId: spaceId,
            name: name,
            type: type.rawValue,
            iconName: iconName,
            iconColorHex: iconColorHex,
            createdBy: actor
        )
        list.pendingSync = true
        context.insert(list)
        try context.save()
        return list
    }

    /// Creates item local.
    func createItemLocal(listId: UUID, title: String, position: Int) throws -> SharedListItem {
        guard let context else { throw RepositoryError.missingLocalContext }
        let item = SharedListItem(listId: listId, title: title, position: position)
        item.pendingSync = true
        context.insert(item)
        try context.save()
        return item
    }

    /// Toggles item local.
    func toggleItemLocal(_ item: SharedListItem, actor: UUID?) throws {
        guard context != nil else { throw RepositoryError.missingLocalContext }
        item.isCompleted.toggle()
        item.updatedBy = actor
        item.updatedAt = .now
        item.version += 1
        item.pendingSync = true
        try context?.save()
    }

    /// Deletes item locally by soft delete.
    func deleteItemLocal(_ item: SharedListItem, actor: UUID?) throws {
        guard context != nil else { throw RepositoryError.missingLocalContext }
        item.deletedAt = .now
        item.updatedBy = actor
        item.updatedAt = .now
        item.version += 1
        item.pendingSync = true
        try context?.save()
    }

    /// Handles upsert list remote.
    private func upsertListRemote(_ list: SharedList) async throws {
        let payload = SharedListPayload(
            id: list.id,
            space_id: list.spaceId,
            name: list.name,
            type: list.type,
            icon_name: list.iconName,
            icon_color_hex: list.iconColorHex,
            created_by: list.createdBy,
            updated_at: list.updatedAt,
            version: list.version,
            updated_by: list.updatedBy,
            deleted_at: list.deletedAt
        )
        do {
            try await client.from("shared_lists").upsert(payload).execute()
        } catch {
            guard shouldFallbackForMissingStyleColumns(error) else { throw error }
            let legacyPayload = SharedListPayloadLegacy(
                id: list.id,
                space_id: list.spaceId,
                name: list.name,
                type: list.type,
                icon_name: list.iconName,
                created_by: list.createdBy,
                updated_at: list.updatedAt,
                version: list.version,
                updated_by: list.updatedBy,
                deleted_at: list.deletedAt
            )
            do {
                try await client.from("shared_lists").upsert(legacyPayload).execute()
            } catch {
                guard shouldFallbackForMissingStyleColumns(error) else { throw error }
                let minimalPayload = SharedListPayloadMinimal(
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
                try await client.from("shared_lists").upsert(minimalPayload).execute()
            }
        }
    }

    /// Handles upsert item remote.
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

    /// Handles pull remote to local.
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
                    local.iconName = record.iconName
                    local.iconColorHex = record.iconColorHex
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
                    iconName: record.iconName,
                    iconColorHex: record.iconColorHex,
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

    /// Syncs pending local.
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

    /// Returns true when remote schema does not include style columns yet.
    private func shouldFallbackForMissingStyleColumns(_ error: Error) -> Bool {
        let text = String(describing: error).lowercased()
        return text.contains("pgrst204") && (text.contains("icon_color_hex") || text.contains("icon_name"))
    }
}
