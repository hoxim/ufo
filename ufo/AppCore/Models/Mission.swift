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
    var ownerId: UUID?
    var dueDate: Date?
    var savedPlaceId: UUID?
    var savedPlaceName: String?
    var priority: String?
    var isRecurring: Bool?
    var space: Space?
    var version: Int = 1
    var lastUpdatedAt: Date
    var updatedAt: Date
    var updatedBy: UUID?
    var deletedAt: Date?
    var pendingSync: Bool = false
    var iconName: String?
    var iconColorHex: String?
    var imageData: Data?
    var visibilityMode: String = SpaceContentVisibilityMode.everyone.rawValue
    
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
        ownerId: UUID? = nil,
        dueDate: Date? = nil,
        savedPlaceId: UUID? = nil,
        savedPlaceName: String? = nil,
        priority: String = MissionPriority.medium.rawValue,
        isRecurring: Bool = false,
        visibilityMode: String = SpaceContentVisibilityMode.everyone.rawValue,
        iconName: String? = nil,
        iconColorHex: String? = "#F59E0B",
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
        self.ownerId = ownerId
        self.dueDate = dueDate
        self.savedPlaceId = savedPlaceId
        self.savedPlaceName = savedPlaceName
        self.priority = priority
        self.isRecurring = isRecurring
        self.visibilityMode = visibilityMode
        self.iconName = iconName
        self.iconColorHex = iconColorHex
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

    var resolvedPriority: String {
        priority ?? MissionPriority.medium.rawValue
    }

    var isRecurringValue: Bool {
        isRecurring ?? false
    }

    var resolvedVisibilityMode: String {
        visibilityMode.isEmpty ? SpaceContentVisibilityMode.everyone.rawValue : visibilityMode
    }
}

enum SpaceContentVisibilityMode: String, CaseIterable, Identifiable {
    case everyone
    case groups
    case `private`

    var id: String { rawValue }
}

enum MissionPriority: String, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var localizedLabel: String {
        switch self {
        case .low:
            return String(localized: "shared.priority.low")
        case .medium:
            return String(localized: "shared.priority.medium")
        case .high:
            return String(localized: "shared.priority.high")
        }
    }
}
