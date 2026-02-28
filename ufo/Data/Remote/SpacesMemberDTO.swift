//
//  SpaceMemberDTO.swift
//  ufo
//
//  Created by Marcin Ryzko on 03/02/2026.
//

import Foundation

struct SpaceMemberDTO: Codable {
    let role: String
    let joinedAt: Date
    let space: SpaceDTO?

    enum CodingKeys: String, CodingKey {
        case role
        case joinedAt = "joined_at"
        case space = "spaces"
    }
}
