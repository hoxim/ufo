import Foundation
import SwiftData

@Model
final class SpaceRoleDefinition {
    @Attribute(.unique) var id: UUID
    var spaceId: UUID
    var name: String
    var key: String
    var canCreateItems: Bool
    var canEditItems: Bool
    var canDeleteItems: Bool
    var canInviteMembers: Bool
    var canManageGroupSettings: Bool
    var canManageRoles: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        spaceId: UUID,
        name: String,
        key: String? = nil,
        canCreateItems: Bool = false,
        canEditItems: Bool = false,
        canDeleteItems: Bool = false,
        canInviteMembers: Bool = false,
        canManageGroupSettings: Bool = false,
        canManageRoles: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.spaceId = spaceId
        self.name = name
        self.key = key ?? Self.makeKey(from: name)
        self.canCreateItems = canCreateItems
        self.canEditItems = canEditItems
        self.canDeleteItems = canDeleteItems
        self.canInviteMembers = canInviteMembers
        self.canManageGroupSettings = canManageGroupSettings
        self.canManageRoles = canManageRoles
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var roleKey: String {
        "\(SpaceRoleDescriptor.customPrefix)\(key)"
    }

    static func makeKey(from value: String) -> String {
        let normalized = value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        let scalars = normalized.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar)) : "-"
        }

        let collapsed = String(scalars)
            .replacingOccurrences(of: "-{2,}", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return collapsed.isEmpty ? UUID().uuidString.lowercased() : collapsed
    }
}

struct SpaceRolePermissions: Equatable, Hashable {
    var canCreateItems: Bool
    var canEditItems: Bool
    var canDeleteItems: Bool
    var canInviteMembers: Bool
    var canManageGroupSettings: Bool
    var canManageRoles: Bool
}

struct SpaceRoleDescriptor: Identifiable, Hashable {
    static let customPrefix = "custom:"

    let key: String
    let name: String
    let permissions: SpaceRolePermissions
    let isBuiltIn: Bool

    var id: String { key }
}

enum SpaceBuiltInRole: String, CaseIterable, Identifiable {
    case admin
    case member
    case contributor
    case viewer

    var id: String { rawValue }

    var descriptor: SpaceRoleDescriptor {
        switch self {
        case .admin:
            SpaceRoleDescriptor(
                key: rawValue,
                name: String(localized: "roles.builtin.admin"),
                permissions: SpaceRolePermissions(
                    canCreateItems: true,
                    canEditItems: true,
                    canDeleteItems: true,
                    canInviteMembers: true,
                    canManageGroupSettings: true,
                    canManageRoles: true
                ),
                isBuiltIn: true
            )
        case .member:
            SpaceRoleDescriptor(
                key: rawValue,
                name: String(localized: "roles.builtin.member"),
                permissions: SpaceRolePermissions(
                    canCreateItems: true,
                    canEditItems: true,
                    canDeleteItems: true,
                    canInviteMembers: false,
                    canManageGroupSettings: false,
                    canManageRoles: false
                ),
                isBuiltIn: true
            )
        case .contributor:
            SpaceRoleDescriptor(
                key: rawValue,
                name: String(localized: "roles.builtin.contributor"),
                permissions: SpaceRolePermissions(
                    canCreateItems: true,
                    canEditItems: false,
                    canDeleteItems: false,
                    canInviteMembers: false,
                    canManageGroupSettings: false,
                    canManageRoles: false
                ),
                isBuiltIn: true
            )
        case .viewer:
            SpaceRoleDescriptor(
                key: rawValue,
                name: String(localized: "roles.builtin.viewer"),
                permissions: SpaceRolePermissions(
                    canCreateItems: false,
                    canEditItems: false,
                    canDeleteItems: false,
                    canInviteMembers: false,
                    canManageGroupSettings: false,
                    canManageRoles: false
                ),
                isBuiltIn: true
            )
        }
    }

    static func descriptor(for rawRole: String) -> SpaceRoleDescriptor? {
        switch rawRole {
        case SpaceBuiltInRole.admin.rawValue:
            return SpaceBuiltInRole.admin.descriptor
        case SpaceBuiltInRole.member.rawValue, "parent":
            return SpaceBuiltInRole.member.descriptor
        case SpaceBuiltInRole.contributor.rawValue, "child":
            return SpaceBuiltInRole.contributor.descriptor
        case SpaceBuiltInRole.viewer.rawValue:
            return SpaceBuiltInRole.viewer.descriptor
        default:
            return nil
        }
    }
}

extension SpaceRoleDescriptor {
    static func resolve(roleKey: String, customRoles: [SpaceRoleDefinition]) -> SpaceRoleDescriptor {
        if let builtIn = SpaceBuiltInRole.descriptor(for: roleKey) {
            return builtIn
        }

        if roleKey.hasPrefix(customPrefix),
           let customRole = customRoles.first(where: { $0.roleKey == roleKey }) {
            return SpaceRoleDescriptor(
                key: roleKey,
                name: customRole.name,
                permissions: SpaceRolePermissions(
                    canCreateItems: customRole.canCreateItems,
                    canEditItems: customRole.canEditItems,
                    canDeleteItems: customRole.canDeleteItems,
                    canInviteMembers: customRole.canInviteMembers,
                    canManageGroupSettings: customRole.canManageGroupSettings,
                    canManageRoles: customRole.canManageRoles
                ),
                isBuiltIn: false
            )
        }

        return SpaceRoleDescriptor(
            key: roleKey,
            name: roleKey.capitalized,
            permissions: SpaceRolePermissions(
                canCreateItems: false,
                canEditItems: false,
                canDeleteItems: false,
                canInviteMembers: false,
                canManageGroupSettings: false,
                canManageRoles: false
            ),
            isBuiltIn: false
        )
    }
}

extension SpaceMembership {
    func resolvedRoleDescriptor(customRoles: [SpaceRoleDefinition]) -> SpaceRoleDescriptor {
        SpaceRoleDescriptor.resolve(roleKey: role, customRoles: customRoles)
    }
}

extension SpaceMemberRecipient {
    func resolvedRoleDescriptor(customRoles: [SpaceRoleDefinition]) -> SpaceRoleDescriptor {
        SpaceRoleDescriptor.resolve(roleKey: role, customRoles: customRoles)
    }
}
