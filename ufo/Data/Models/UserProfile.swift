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
    var role: String
    
    @Relationship(deleteRule: .cascade, inverse: \SpaceMembership.user)
    var memberships: [SpaceMembership] = []

    var assignedMissions: [Mission] = []

    init(id: UUID, email: String, fullName: String? = nil, role: String = "user") {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.role = role
    }
}
