import Foundation
import SwiftData

@Model
final class SpaceMessage {
    @Attribute(.unique) var id: UUID
    var spaceId: UUID
    var senderId: UUID
    var senderName: String
    var body: String
    var recipientIdsRaw: String
    var sentAt: Date
    var createdAt: Date
    var updatedAt: Date
    var version: Int
    var updatedBy: UUID?
    var deletedAt: Date?
    var pendingSync: Bool

    init(
        id: UUID = UUID(),
        spaceId: UUID,
        senderId: UUID,
        senderName: String,
        body: String,
        recipientIds: [UUID] = [],
        sentAt: Date = .now
    ) {
        self.id = id
        self.spaceId = spaceId
        self.senderId = senderId
        self.senderName = senderName
        self.body = body
        self.recipientIdsRaw = recipientIds.map(\.uuidString).joined(separator: ",")
        self.sentAt = sentAt
        self.createdAt = .now
        self.updatedAt = .now
        self.version = 1
        self.updatedBy = nil
        self.deletedAt = nil
        self.pendingSync = false
    }

    var recipientIds: [UUID] {
        recipientIdsRaw
            .split(separator: ",")
            .compactMap { UUID(uuidString: String($0)) }
    }
}
