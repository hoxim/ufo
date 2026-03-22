import Foundation
import SwiftData

@Model
final class SpaceVisibilityGroup {
    @Attribute(.unique) var id: UUID
    var spaceId: UUID
    var key: String
    var name: String
    var iconName: String?
    var colorHex: String?
    var isSystem: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
    var version: Int
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        spaceId: UUID,
        key: String,
        name: String,
        iconName: String? = nil,
        colorHex: String? = nil,
        isSystem: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        version: Int = 1,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.spaceId = spaceId
        self.key = key
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.isSystem = isSystem
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.deletedAt = deletedAt
    }
}
