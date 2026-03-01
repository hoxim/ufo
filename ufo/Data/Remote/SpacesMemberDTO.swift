//
//  SpaceMemberDTO.swift
//  ufo
//
//  Created by Marcin Ryzko on 03/02/2026.
//

import Foundation

struct SpaceMemberDTO: Codable {
    let userId: UUID
    let role: String
    let joinedAt: Date
    let profile: SpaceMemberUserDTO?
    let space: SpaceDTO?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case role
        case joinedAt = "joined_at"
        case profile = "profiles"
        case space = "spaces"
    }
}
