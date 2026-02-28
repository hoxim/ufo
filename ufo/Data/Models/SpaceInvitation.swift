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
    var spaceId: UUID
    var inviterId: UUID?
    var inviteeEmail: String
    var inviteCode: String
    var status: String
    var sentAt: Date
    var expiresAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var spaceName: String
    
    init(id: UUID,
         spaceId: UUID,
         inviterId: UUID?,
         inviteeEmail: String,
         inviteCode: String,
         status: String,
         sentAt: Date = Date(),
         expiresAt: Date? = nil,
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         spaceName: String) {
        
        self.id = id
        self.spaceId = spaceId
        self.inviterId = inviterId
        self.inviteeEmail = inviteeEmail
        self.inviteCode = inviteCode
        self.status = status
        self.sentAt = sentAt
        self.expiresAt = expiresAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.spaceName = spaceName
    }
}
