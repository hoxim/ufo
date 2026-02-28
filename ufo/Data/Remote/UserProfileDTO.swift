//
//  UserProfileDTO.swift
//  ufo
//
//  Created by Marcin Ryzko on 03/02/2026.
//

import Foundation

struct UserProfileDTO: Codable {
    let id: UUID
    let email: String?
    let fullName: String?
    let avatarUrl: String?
    let spaceMembers: [SpaceMemberDTO]?

    enum CodingKeys: String, CodingKey {
        case id, email
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case spaceMembers = "space_members"
    }
}
