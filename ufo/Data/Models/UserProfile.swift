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
    var role: String // Ogólna rola systemowa (np. "user")
    
    // Relacja: Użytkownik ma wiele członkostw w grupach
    @Relationship(deleteRule: .cascade, inverse: \GroupMembership.user)
    var memberships: [GroupMembership] = []
    
    // Relacja: Misje przypisane bezpośrednio do tego użytkownika
    @Relationship(deleteRule: .noAction, inverse: \Mission.assignees)
    var assignedMissions: [Mission] = []

    init(id: UUID, email: String, fullName: String? = nil, role: String = "user") {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.role = role
    }
}
