//
//  SpaceDTO.swift
//  ufo
//
//  Created by Marcin Ryzko on 03/02/2026.
//

import Foundation

struct SpaceDTO: Codable {
    let id: UUID
    let name: String
    let inviteCode: String
    let category: String?
    let version: Int?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, category, version
        case inviteCode = "invite_code"
        case updatedAt = "updated_at"
    }
}
