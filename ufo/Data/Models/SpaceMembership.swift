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
    @Attribute(.unique) var id: String // Format: "userID_spaceID"
    var role: String // "admin", "member", "parent", "child"
    var joinedAt: Date
    
    var user: UserProfile?
    var space: Space?

    init(user: UserProfile, space: Space, role: String = "member") {
        self.id = "\(user.id.uuidString)_\(space.id.uuidString)"
        self.user = user
        self.space = space
        self.role = role
        self.joinedAt = Date()
    }
}
