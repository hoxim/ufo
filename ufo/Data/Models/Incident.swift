//
//  Incident.swift
//  ufo
//
//  Created by Marcin Ryzko on 09/02/2026.
//

import Foundation
import SwiftData

@Model
final class Incident: Thing {

    @Attribute(.unique) var id: UUID
    var spaceId: UUID
    var createdBy: UUID?
    var title: String
    var incidentDescription: String?
    var createdAt: Date
    var occurrenceDate: Date
    var version: Int = 1
    var lastUpdatedAt: Date
    var updatedAt: Date
    var updatedBy: UUID?
    var deletedAt: Date?
    var pendingSync: Bool = false
    var iconName: String?
    var imageData: Data?
    

    @Relationship(deleteRule: .cascade)
    var links: [LinkedThing] = []

    init(
        id: UUID = UUID(),
        spaceId: UUID,
        title: String,
        incidentDescription: String? = nil,
        occurrenceDate: Date,
        iconName: String? = nil,
        imageData: Data? = nil,
        createdBy: UUID? = nil
    ) {
        self.id = id
        self.spaceId = spaceId
        self.createdBy = createdBy
        self.title = title
        self.incidentDescription = incidentDescription
        self.iconName = iconName
        self.imageData = imageData
        self.createdAt = .now
        self.occurrenceDate = occurrenceDate
        self.lastUpdatedAt = .now
        self.updatedAt = .now
    }
}

extension Incident {
    @Transient
    var subThings: [any Thing] {
        return []
    }
}
