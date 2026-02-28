//
//  MissionDTO.swift
//  ufo
//
//  Created by Marcin Ryzko on 22/02/2026.
//

import Foundation

struct MissionDTO: Codable {
    let id: UUID
    let groupId: UUID
    let title: String
    let description: String
    let difficulty: Int
    let isCompleted: Bool
    let version: Int
    let lastUpdatedAt: Date
}
