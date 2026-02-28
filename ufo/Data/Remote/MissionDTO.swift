//
//  MissionDTO.swift
//  ufo
//
//  Created by Marcin Ryzko on 22/02/2026.
//

import Foundation

struct MissionDTO: Codable {
    let id: UUID
    let spaceId: UUID
    let title: String
    let description: String
    let difficulty: Int
    let isCompleted: Bool
    let version: Int
    let lastUpdatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, difficulty, version
        case spaceId = "space_id"
        case isCompleted = "is_completed"
        case lastUpdatedAt = "last_updated_at"
    }
}
