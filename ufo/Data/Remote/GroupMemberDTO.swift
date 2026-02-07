//
//  GroupMemberDTO.swift
//  ufo
//
//  Created by Marcin Ryzko on 03/02/2026.
//

import Foundation

struct GroupMemberDTO: Codable {
    let role: String
    let joinedAt: Date
    // Supabase zwraca zagnieżdżony obiekt grupy wewnątrz członkowstwa
    let group: GroupDTO?

    enum CodingKeys: String, CodingKey {
        case role
        case joinedAt = "joined_at"
        case group = "groups" // Supabase domyślnie nazywa relację tak jak tabelę docelową
    }
}
