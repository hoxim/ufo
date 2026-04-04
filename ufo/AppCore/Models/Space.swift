//
//  Space.swift
//  ufo
//
//  Created by Marcin Ryzko on 30/01/2026.
//

import Foundation
import SwiftData

@Model
final class Space {
    @Attribute(.unique) var id: UUID
    var name: String
    var inviteCode: String
    var category: String
    var createdAt: Date
    var updatedAt: Date
    var version: Int
    var createdBy: UUID?
    var updatedBy: UUID?
    
    @Relationship(deleteRule: .cascade, inverse: \SpaceMembership.space)
    var members: [SpaceMembership] = []

    @Relationship(deleteRule: .cascade, inverse: \Mission.space)
    var missions: [Mission] = []
    
    init(
        id: UUID,
        name: String,
        inviteCode: String,
        category: String = SpaceType.family.rawValue,
        createdBy: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        version: Int = 1,
        updatedBy: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.inviteCode = inviteCode
        self.category = category
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.updatedBy = updatedBy
    }
}

enum SpaceType: String, Codable, CaseIterable, Identifiable {
    case `private` = "Private"
    case shared = "Shared"
    case family = "Family"
    case work = "Work"
    case personal = "Personal"
    
    var id: String { self.rawValue }

    var allowsInvitations: Bool {
        switch self {
        case .private, .personal:
            return false
        case .shared, .family, .work:
            return true
        }
    }

    var displayName: String {
        switch self {
        case .private, .personal:
            return String(localized: "spaces.type.private")
        case .shared, .family, .work:
            return String(localized: "spaces.type.shared")
        }
    }
}

extension SpaceType {
    init(category: String) {
        self = SpaceType(rawValue: category) ?? .shared
    }
}

extension Space {
    var type: SpaceType {
        SpaceType(category: category)
    }

    var allowsInvitations: Bool {
        type.allowsInvitations
    }
}
