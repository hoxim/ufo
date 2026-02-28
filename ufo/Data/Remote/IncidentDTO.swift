//
//  IncidentDTO.swift
//  ufo
//
//  Created by Marcin Ryzko on 09/02/2026.
//

import Foundation

struct IncidentDTO: Codable {
    let id: UUID
    let space_id: UUID
    let created_by: UUID
    let title: String
    let description: String
    let occurrence_date: Date
}
