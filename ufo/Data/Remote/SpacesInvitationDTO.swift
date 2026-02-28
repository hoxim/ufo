//
//  SpaceInvitationDTO.swift
//  ufo
//
//  Created by Marcin Ryzko on 09/02/2026.
//

import Foundation

struct SpaceInvitationDTO: Codable {
    let id: UUID
    let spaceId: UUID
    let inviterId: UUID?
    let inviteeEmail: String
    let inviteCode: String
    let status: String
    let sentAt: Date
    let expiresAt: Date?
    
    let space: SpaceDTO?

    enum CodingKeys: String, CodingKey {
        case id, status
        case spaceId = "space_id"
        case inviterId = "inviter_id"
        case inviteeEmail = "invitee_email"
        case inviteCode = "invite_code"
        case sentAt = "sent_at"
        case expiresAt = "expires_at"
        case space = "spaces"
    }
}
