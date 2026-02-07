//
//  Group.swift
//  ufo
//
//  Created by Marcin Ryzko on 30/01/2026.
//

import Foundation
import SwiftData

@Model
final class Group {
    @Attribute(.unique) var id: UUID
    var name: String
    var inviteCode: String
    
    // Relacja: Grupa ma wielu członków (tabela łącząca)
    @Relationship(deleteRule: .cascade, inverse: \GroupMembership.group)
    var members: [GroupMembership] = []
    
    @Relationship(deleteRule: .cascade, inverse: \GroupInvitation.group)
    var activeInvitations: [GroupInvitation] = []
    
    // Relacja: Wszystkie misje/zadania należące do tej grupy
    @Relationship(deleteRule: .cascade, inverse: \Mission.group)
    var missions: [Mission] = []

    init(id: UUID, name: String, inviteCode: String) {
        self.id = id
        self.name = name
        self.inviteCode = inviteCode
    }
}
