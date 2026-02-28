//
//  SpaceInvitation.swift
//  ufo
//
//  Created by Marcin Ryzko on 30/01/2026.
//
import SwiftData
import Foundation

@Model
final class SpaceInvitation {
    @Attribute(.unique) var id: UUID
    var spaceID: UUID
    var inviterID: UUID
    var inviteeEmail: String
    var status: String
    var receivedAt: Date
    var spaceName: String
    
    init(id: UUID,
         spaceID: UUID,
         inviterID: UUID,
         inviteeEmail: String,
         status: String,
         receivedAt: Date = Date(),
         spaceName: String) {
        
        self.id = id
        self.spaceID = spaceID
        self.inviterID = inviterID
        self.inviteeEmail = inviteeEmail
        self.status = status
        self.receivedAt = receivedAt
        self.spaceName = spaceName
    }
}
