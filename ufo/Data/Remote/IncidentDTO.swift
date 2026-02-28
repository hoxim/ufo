//
//  IncidentDTO.swift
//  ufo
//
//  Created by Marcin Ryzko on 09/02/2026.
//

import Foundation

struct IncidentDTO: Codable {
    let id: UUID
    let spaceId: UUID
    let createdBy: UUID
    let title: String
    let description: String?
    let occurrenceDate: Date
    let version: Int
    let lastUpdatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, version
        case spaceId = "space_id"
        case createdBy = "created_by"
        case occurrenceDate = "occurrence_date"
        case lastUpdatedAt = "last_updated_at"
    }
}
