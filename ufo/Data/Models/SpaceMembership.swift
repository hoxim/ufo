//
//  SpaceMemebership.swift
//  ufo
//
//  Created by Marcin Ryzko on 03/02/2026.
//

import Foundation
import SwiftData

@Model
final class SpaceMembership {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var spaceId: UUID
    var role: String // "admin", "member", "parent", "child"
    var joinedAt: Date
    var createdAt: Date
    var updatedAt: Date
    
    var user: UserProfile?
    var space: Space?

    init(
        id: UUID = UUID(),
        userId: UUID,
        spaceId: UUID,
        role: String = "member",
        joinedAt: Date = .now,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        user: UserProfile? = nil,
        space: Space? = nil
    ) {
        self.id = id
        self.userId = userId
        self.spaceId = spaceId
        self.role = role
        self.joinedAt = joinedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.user = user
        self.space = space
    }

    convenience init(user: UserProfile, space: Space, role: String = "member") {
        self.init(
            userId: user.id,
            spaceId: space.id,
            role: role,
            user: user,
            space: space
        )
    }
}
