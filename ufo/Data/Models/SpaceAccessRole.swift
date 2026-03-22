import Foundation
import SwiftData

@Model
final class SpaceAccessRole {
    @Attribute(.unique) var id: UUID
    var spaceId: UUID
    var key: String
    var name: String
    var canCreateItems: Bool
    var canEditItems: Bool
    var canDeleteItems: Bool
    var canInviteMembers: Bool
    var canManageGroupSettings: Bool
    var canManageRoles: Bool
    var isSystem: Bool
    var isDefault: Bool
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
        canCreateItems: Bool = false,
        canEditItems: Bool = false,
        canDeleteItems: Bool = false,
        canInviteMembers: Bool = false,
        canManageGroupSettings: Bool = false,
        canManageRoles: Bool = false,
        isSystem: Bool = false,
        isDefault: Bool = false,
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
        self.canCreateItems = canCreateItems
        self.canEditItems = canEditItems
        self.canDeleteItems = canDeleteItems
        self.canInviteMembers = canInviteMembers
        self.canManageGroupSettings = canManageGroupSettings
        self.canManageRoles = canManageRoles
        self.isSystem = isSystem
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.deletedAt = deletedAt
    }
}
