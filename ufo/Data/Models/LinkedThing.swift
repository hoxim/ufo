
import Foundation
import SwiftData

@Model
final class LinkedThing {
    @Attribute(.unique) var id: UUID
    var thingId: UUID?
    var parentId: UUID    // ID incident/mission (parent)
    var childId: UUID     // ID attached thing (child)
    var createdAt: Date
    var updatedAt: Date
    var version: Int
    var updatedBy: UUID?
    var deletedAt: Date?
    var pendingSync: Bool
    
    init(
        id: UUID = UUID(),
        thingId: UUID? = nil,
        parentId: UUID,
        childId: UUID,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        version: Int = 1,
        updatedBy: UUID? = nil,
        deletedAt: Date? = nil,
        pendingSync: Bool = false
    ) {
        self.id = id
        self.thingId = thingId
        self.parentId = parentId
        self.childId = childId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.updatedBy = updatedBy
        self.deletedAt = deletedAt
        self.pendingSync = pendingSync
    }
}
