//
//  GroupMemebership.swift
//  ufo
//
//  Created by Marcin Ryzko on 03/02/2026.
//

import Foundation
import SwiftData

@Model
final class GroupMembership {
    @Attribute(.unique) var id: String // Format: "userID_groupID"
    var role: String // "admin", "member", "parent", "child"
    var joinedAt: Date
    
    var user: UserProfile?
    var group: Group?

    init(user: UserProfile, group: Group, role: String = "member") {
        self.id = "\(user.id.uuidString)_\(group.id.uuidString)"
        self.user = user
        self.group = group
        self.role = role
        self.joinedAt = Date()
    }
}
