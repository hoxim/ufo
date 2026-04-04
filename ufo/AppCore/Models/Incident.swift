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
    var severity: String?
    var status: String?
    var assigneeId: UUID?
    var cost: Double?
    var createdAt: Date
    var occurrenceDate: Date
    var version: Int = 1
    var lastUpdatedAt: Date
    var updatedAt: Date
    var updatedBy: UUID?
    var deletedAt: Date?
    var pendingSync: Bool = false
    var iconName: String?
    var iconColorHex: String?
    var imageData: Data?
    

    @Relationship(deleteRule: .cascade)
    var links: [LinkedThing] = []

    init(
        id: UUID = UUID(),
        spaceId: UUID,
        title: String,
        incidentDescription: String? = nil,
        severity: String = IncidentSeverity.medium.rawValue,
        status: String = IncidentStatus.open.rawValue,
        assigneeId: UUID? = nil,
        cost: Double? = nil,
        occurrenceDate: Date,
        iconName: String? = nil,
        iconColorHex: String? = "#F59E0B",
        imageData: Data? = nil,
        createdBy: UUID? = nil
    ) {
        self.id = id
        self.spaceId = spaceId
        self.createdBy = createdBy
        self.title = title
        self.incidentDescription = incidentDescription
        self.severity = severity
        self.status = status
        self.assigneeId = assigneeId
        self.cost = cost
        self.iconName = iconName
        self.iconColorHex = iconColorHex
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

    var resolvedSeverity: String {
        severity ?? IncidentSeverity.medium.rawValue
    }

    var resolvedStatus: String {
        status ?? IncidentStatus.open.rawValue
    }
}

enum IncidentSeverity: String, CaseIterable, Identifiable {
    case low
    case medium
    case high
    case critical

    var id: String { rawValue }

    var localizedLabel: String {
        switch self {
        case .low:
            return String(localized: "shared.priority.low")
        case .medium:
            return String(localized: "shared.priority.medium")
        case .high:
            return String(localized: "shared.priority.high")
        case .critical:
            return String(localized: "shared.priority.critical")
        }
    }
}

enum IncidentStatus: String, CaseIterable, Identifiable {
    case open
    case inProgress = "in_progress"
    case resolved

    var id: String { rawValue }

    var localizedLabel: String {
        switch self {
        case .open:
            return String(localized: "shared.status.open")
        case .inProgress:
            return String(localized: "shared.status.inProgress")
        case .resolved:
            return String(localized: "shared.status.resolved")
        }
    }
}
