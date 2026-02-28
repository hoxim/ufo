import Foundation
import SwiftData

@Model
final class Assignment {
    @Attribute(.unique) var id: UUID
    var thingId: UUID
    var userId: UUID?
    var role: String
    var createdAt: Date
    var updatedAt: Date
    var version: Int
    var updatedBy: UUID?
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        thingId: UUID,
        userId: UUID? = nil,
        role: String = "member",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        version: Int = 1,
        updatedBy: UUID? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.thingId = thingId
        self.userId = userId
        self.role = role
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.updatedBy = updatedBy
        self.deletedAt = deletedAt
    }
}
