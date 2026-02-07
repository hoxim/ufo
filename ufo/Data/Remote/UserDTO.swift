//
//  UserDTO.swift
//  ufo
//
//  Created by Marcin Ryzko on 30/01/2026.
//

import Foundation

struct UserDTO: Codable {
    let id: UUID
    let email: String
    let fullName: String?
    let avatarUrl: String?
    let role: String?
    let groupMembers: [MembershipDTO]?

    enum CodingKeys: String, CodingKey {
        case id, email, role
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case groupMembers = "group_members"
    }
}
