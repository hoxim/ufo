//
//  GroupInvitation.swift
//  ufo
//
//  Created by Marcin Ryzko on 30/01/2026.
//

import Foundation
import SwiftData

@Model
final class GroupInvitation {
    @Attribute(.unique) var id: UUID
    var inviteCode: String
    var status: String
    var sentAt: Date
    var expiresAt: Date?
    
    // Kto zaprasza? (np. Ty jako Admin)
    @Relationship(deleteRule: .noAction)
    var inviter: UserProfile?
    var group: Group?
    var inviteeEmail: String?

    init(id: UUID, group: Group, inviter: UserProfile, email: String?) {
        self.id = id
        self.group = group
        self.inviter = inviter
        self.inviteeEmail = email
        self.inviteCode = String(UUID().uuidString.prefix(6)).uppercased()
        self.status = "pending"
        self.sentAt = Date()
        // Domyślnie ważne np. 7 dni
        self.expiresAt = Calendar.current.date(byAdding: .day, value: 7, to: Date())
    }
}
