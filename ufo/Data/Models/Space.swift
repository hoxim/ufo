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
    
    @Relationship(deleteRule: .cascade, inverse: \SpaceMembership.space)
    var members: [SpaceMembership] = []

    @Relationship(deleteRule: .cascade, inverse: \Mission.space)
    var missions: [Mission] = []
    
    var avatarUrl:String?

    init(id: UUID, name: String, inviteCode: String) {
        self.id = id
        self.name = name
        self.inviteCode = inviteCode
    }
}

enum SpaceType: String, Codable, CaseIterable, Identifiable {
    case family = "Family"
    case work = "Work"
    case personal = "Personal"
    
    var id: String { self.rawValue }
}
