import Foundation
import SwiftData

@Model
final class MissionVisibilityGroup {
    @Attribute(.unique) var id: UUID
    var missionId: UUID
    var groupId: UUID
    var spaceId: UUID
    var createdAt: Date

    init(
        id: UUID = UUID(),
        missionId: UUID,
        groupId: UUID,
        spaceId: UUID,
        createdAt: Date = .now
    ) {
        self.id = id
        self.missionId = missionId
        self.groupId = groupId
        self.spaceId = spaceId
        self.createdAt = createdAt
    }
}
