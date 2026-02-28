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
    var title: String
    var createdAt: Date
    var occurrenceDate: Date
    var assignedUserIds: [UUID] = []
    

    @Relationship(deleteRule: .cascade)
    var links: [LinkedThing] = []

    init(id: UUID = UUID(), spaceId: UUID, title: String, occurrenceDate: Date) {
        self.id = id
        self.spaceId = spaceId
        self.title = title
        self.createdAt = .now
        self.occurrenceDate = occurrenceDate
    }
}

extension Incident {
    @Transient
    var subThings: [any Thing] {
        return []
    }
}
