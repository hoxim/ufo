import Foundation
import SwiftData

@Model
final class Incident: Thing {
    @Attribute(.unique) var id: UUID
    var spaceId: UUID
    var createdBy: UUID?
    var title: String
    var incidentDescription: String?
    var severity: IncidentSeverity = .medium
    var status: IncidentStatus = .open
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
        severity: IncidentSeverity = .medium,
        status: IncidentStatus = .open,
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
    var subThings: [any Thing] { [] }
}

enum IncidentSeverity: String, CaseIterable, Codable, Identifiable {
    case low
    case medium
    case high
    case critical

    var id: String { rawValue }

    var localizedLabel: String {
        switch self {
        case .low:      String(localized: "shared.priority.low")
        case .medium:   String(localized: "shared.priority.medium")
        case .high:     String(localized: "shared.priority.high")
        case .critical: String(localized: "shared.priority.critical")
        }
    }
}

enum IncidentStatus: String, CaseIterable, Codable, Identifiable {
    case open
    case inProgress = "in_progress"
    case resolved

    var id: String { rawValue }

    var localizedLabel: String {
        switch self {
        case .open:       String(localized: "shared.status.open")
        case .inProgress: String(localized: "shared.status.inProgress")
        case .resolved:   String(localized: "shared.status.resolved")
        }
    }
}
