//
//  Mission.swift
//  ufo
//
//  Created by Marcin Ryzko on 30/01/2026.
//


import Foundation
import SwiftData

@Model
final class Mission: Thing {
    @Attribute(.unique) var id: UUID
    var spaceId: UUID
    var title: String
    var createdAt: Date
    var createdBy: UUID?
    var missionDescription: String = ""
    var isCompleted: Bool = false
    var difficulty: Int = 1
    var space: Space?
    var version: Int = 1
    var lastUpdatedAt: Date
    var updatedAt: Date
    var updatedBy: UUID?
    var deletedAt: Date?
    var pendingSync: Bool = false
    var iconName: String?
    var imageData: Data?
    
    // relation to  UserProfile
    @Relationship(inverse: \UserProfile.assignedMissions)
    var assignees: [UserProfile] = []

    @Relationship(deleteRule: .cascade)
    var links: [LinkedThing] = []

    init(
        id: UUID = UUID(),
        spaceId: UUID,
        title: String,
        missionDescription: String = "",
        difficulty: Int = 1,
        iconName: String? = nil,
        imageData: Data? = nil,
        createdBy: UUID? = nil
    ) {
        self.id = id
        self.spaceId = spaceId
        self.title = title
        self.createdAt = .now
        self.createdBy = createdBy
        self.missionDescription = missionDescription
        self.difficulty = difficulty
        self.iconName = iconName
        self.imageData = imageData
        self.isCompleted = false
        self.lastUpdatedAt = .now
        self.updatedAt = .now
    }
}

extension Mission {
    @Transient
    var subThings: [any Thing] {
        return []
    }
}
