import Foundation
import SwiftData
import Supabase

@MainActor
final class MessageRepository {
    private let client: SupabaseClient
    private let context: ModelContext?

    init(client: SupabaseClient, context: ModelContext? = nil) {
        self.client = client
        self.context = context
    }

    struct MessageRecord: Codable {
        let id: UUID
        let spaceId: UUID
        let senderId: UUID
        let senderName: String
        let body: String
        let recipientIds: [UUID]?
        let sentAt: Date
        let createdAt: Date?
        let updatedAt: Date?
        let version: Int
        let updatedBy: UUID?
        let deletedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id, body, version
            case spaceId = "space_id"
            case senderId = "sender_id"
            case senderName = "sender_name"
            case recipientIds = "recipient_ids"
            case sentAt = "sent_at"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case updatedBy = "updated_by"
            case deletedAt = "deleted_at"
        }
    }

    private struct MessagePayload: Encodable {
        let id: UUID
        let space_id: UUID
        let sender_id: UUID
        let sender_name: String
        let body: String
        let recipient_ids: [UUID]
        let sent_at: Date
        let updated_at: Date
        let version: Int
        let updated_by: UUID?
        let deleted_at: Date?
    }

    /// Fetches local.
    func fetchLocal(spaceId: UUID) throws -> [SpaceMessage] {
        guard let context else { return [] }
        return try context.fetch(
            FetchDescriptor<SpaceMessage>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.sentAt, order: .forward)]
            )
        )
    }

    /// Creates local.
    func createLocal(spaceId: UUID, senderId: UUID, senderName: String, body: String, recipientIds: [UUID]) throws -> SpaceMessage {
        guard let context else { throw RepositoryError.missingLocalContext }
        let message = SpaceMessage(
            spaceId: spaceId,
            senderId: senderId,
            senderName: senderName,
            body: body,
            recipientIds: recipientIds,
            sentAt: .now
        )
        message.pendingSync = true
        context.insert(message)
        try context.save()
        return message
    }

    /// Handles upsert remote.
    private func upsertRemote(_ message: SpaceMessage) async throws {
        let payload = MessagePayload(
            id: message.id,
            space_id: message.spaceId,
            sender_id: message.senderId,
            sender_name: message.senderName,
            body: message.body,
            recipient_ids: message.recipientIds,
            sent_at: message.sentAt,
            updated_at: message.updatedAt,
            version: message.version,
            updated_by: message.updatedBy,
            deleted_at: message.deletedAt
        )

        try await client.from("space_messages").upsert(payload).execute()
    }

    /// Handles pull remote to local.
    func pullRemoteToLocal(spaceId: UUID) async throws {
        guard let context else { return }
        let remote: [MessageRecord] = try await client
            .from("space_messages")
            .select("*")
            .eq("space_id", value: spaceId)
            .is("deleted_at", value: nil)
            .order("sent_at", ascending: true)
            .limit(300)
            .execute()
            .value

        for record in remote {
            let local = try context.fetch(FetchDescriptor<SpaceMessage>(predicate: #Predicate { $0.id == record.id })).first
            if let local {
                if local.version <= record.version {
                    local.senderId = record.senderId
                    local.senderName = record.senderName
                    local.body = record.body
                    let recipientIds = record.recipientIds ?? []
                    local.recipientIdsRaw = recipientIds.map(\.uuidString).joined(separator: ",")
                    local.sentAt = record.sentAt
                    local.createdAt = record.createdAt ?? local.createdAt
                    local.updatedAt = record.updatedAt ?? local.updatedAt
                    local.version = record.version
                    local.updatedBy = record.updatedBy
                    local.deletedAt = record.deletedAt
                    local.pendingSync = false
                }
            } else {
                let msg = SpaceMessage(
                    id: record.id,
                    spaceId: record.spaceId,
                    senderId: record.senderId,
                    senderName: record.senderName,
                    body: record.body,
                    recipientIds: record.recipientIds ?? [],
                    sentAt: record.sentAt
                )
                msg.createdAt = record.createdAt ?? .now
                msg.updatedAt = record.updatedAt ?? .now
                msg.version = record.version
                msg.updatedBy = record.updatedBy
                msg.deletedAt = record.deletedAt
                msg.pendingSync = false
                context.insert(msg)
            }
        }

        try context.save()
    }

    /// Syncs pending local.
    func syncPendingLocal(spaceId: UUID) async throws {
        guard let context else { return }
        let pending = try context.fetch(
            FetchDescriptor<SpaceMessage>(predicate: #Predicate { $0.spaceId == spaceId && $0.pendingSync == true })
        )

        for msg in pending {
            try await upsertRemote(msg)
            msg.pendingSync = false
        }

        try context.save()
    }
}
