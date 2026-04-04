import Foundation
import SwiftData

@Model
final class SharedList {
    @Attribute(.unique) var id: UUID
    var spaceId: UUID
    var name: String
    var type: String
    var iconName: String?
    var iconColorHex: String?
    var savedPlaceId: UUID?
    var savedPlaceName: String?
    var createdBy: UUID?
    var createdAt: Date
    var updatedAt: Date
    var version: Int
    var updatedBy: UUID?
    var deletedAt: Date?
    var pendingSync: Bool

    @Relationship(deleteRule: .cascade)
    var items: [SharedListItem] = []

    init(
        id: UUID = UUID(),
        spaceId: UUID,
        name: String,
        type: String = "shopping",
        iconName: String? = "checklist",
        iconColorHex: String? = "#6366F1",
        savedPlaceId: UUID? = nil,
        savedPlaceName: String? = nil,
        createdBy: UUID? = nil
    ) {
        self.id = id
        self.spaceId = spaceId
        self.name = name
        self.type = type
        self.iconName = iconName
        self.iconColorHex = iconColorHex
        self.savedPlaceId = savedPlaceId
        self.savedPlaceName = savedPlaceName
        self.createdBy = createdBy
        self.createdAt = .now
        self.updatedAt = .now
        self.version = 1
        self.updatedBy = nil
        self.deletedAt = nil
        self.pendingSync = false
    }
}

enum SharedListType: String, CaseIterable, Identifiable {
    case shopping = "shopping"
    case goals = "goals"

    var id: String { rawValue }

    var localizedLabel: String {
        switch self {
        case .shopping:
            return String(localized: "lists.type.shopping")
        case .goals:
            return String(localized: "lists.type.goals")
        }
    }
}
