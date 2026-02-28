//
//  SpaceInvitationDTO.swift
//  ufo
//
//  Created by Marcin Ryzko on 09/02/2026.
//

import Foundation

struct SpaceInvitationDTO: Codable {
    let id: UUID
    let space_id: UUID
    let inviter_id: UUID
    let invitee_email: String
    let invite_code: String
    let status: String
    let sent_at: Date
    let expires_at: Date?
    
    let space: SpaceDTO?

    enum CodingKeys: String, CodingKey {
        case id, space_id, inviter_id, invitee_email, invite_code, status
        case sent_at, expires_at
        case space = "spaces"
    }
}
