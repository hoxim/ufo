import Foundation
import SwiftData

@Model
final class SpaceVisibilityGroupMember {
    @Attribute(.unique) var id: UUID
    var groupId: UUID
    var spaceId: UUID
    var userId: UUID
    var createdAt: Date

    init(
        id: UUID = UUID(),
        groupId: UUID,
        spaceId: UUID,
        userId: UUID,
        createdAt: Date = .now
    ) {
        self.id = id
        self.groupId = groupId
        self.spaceId = spaceId
        self.userId = userId
        self.createdAt = createdAt
    }
}
