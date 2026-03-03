//
//  UserProfile.swift
//  ufo
//
//  Created by Marcin Ryzko on 03/02/2026.
//

import Foundation
import SwiftData


@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var email: String
    var fullName: String?
    var avatarURL: String?
    var avatarVersion: Int
    var role: String
    
    @Relationship(deleteRule: .cascade, inverse: \SpaceMembership.user)
    var memberships: [SpaceMembership] = []

    var assignedMissions: [Mission] = []

    init(id: UUID, email: String, fullName: String? = nil, avatarVersion: Int = 1, role: String = "user") {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.avatarVersion = avatarVersion
        self.role = role
    }

    /// Backward-compatible initializer kept for existing call sites and generated symbols.
    convenience init(id: UUID, email: String, fullName: String? = nil, role: String) {
        self.init(
            id: id,
            email: email,
            fullName: fullName,
            avatarVersion: 1,
            role: role
        )
    }
}
