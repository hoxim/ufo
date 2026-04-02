import Foundation
import SwiftData

@Model
final class LocationPing {
    @Attribute(.unique) var id: UUID
    var spaceId: UUID
    var userId: UUID
    var userDisplayName: String
    var latitude: Double
    var longitude: Double
    var recordedAt: Date
    var createdAt: Date
    var updatedAt: Date
    var version: Int
    var updatedBy: UUID?
    var deletedAt: Date?
    var pendingSync: Bool

    init(
        id: UUID = UUID(),
        spaceId: UUID,
        userId: UUID,
        userDisplayName: String,
        latitude: Double,
        longitude: Double,
        recordedAt: Date = .now
    ) {
        self.id = id
        self.spaceId = spaceId
        self.userId = userId
        self.userDisplayName = userDisplayName
        self.latitude = latitude
        self.longitude = longitude
        self.recordedAt = recordedAt
        self.createdAt = .now
        self.updatedAt = .now
        self.version = 1
        self.updatedBy = nil
        self.deletedAt = nil
        self.pendingSync = false
    }
}

@Model
final class SavedPlace {
    @Attribute(.unique) var id: UUID
    var spaceId: UUID
    var name: String
    var placeDescription: String?
    var category: String?
    var iconName: String?
    var iconColorHex: String?
    var address: String?
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
    var createdBy: UUID?
    var createdAt: Date
    var updatedAt: Date
    var version: Int
    var updatedBy: UUID?
    var deletedAt: Date?
    var pendingSync: Bool

    init(
        id: UUID = UUID(),
        spaceId: UUID,
        name: String,
        placeDescription: String? = nil,
        category: String? = nil,
        iconName: String? = nil,
        iconColorHex: String? = nil,
        address: String? = nil,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double = 100,
        createdBy: UUID? = nil
    ) {
        self.id = id
        self.spaceId = spaceId
        self.name = name
        self.placeDescription = placeDescription
        self.category = category
        self.iconName = iconName
        self.iconColorHex = iconColorHex
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.createdBy = createdBy
        self.createdAt = .now
        self.updatedAt = .now
        self.version = 1
        self.updatedBy = nil
        self.deletedAt = nil
        self.pendingSync = false
    }
}

extension SavedPlace {
    var resolvedCategory: SavedPlaceCategory {
        SavedPlaceCategory(rawValue: category ?? "") ?? .other
    }
}

enum SavedPlaceCategory: String, CaseIterable, Identifiable {
    case home
    case school
    case work
    case doctor
    case activity
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .school:
            return "School"
        case .work:
            return "Work"
        case .doctor:
            return "Doctor"
        case .activity:
            return "Activity"
        case .other:
            return "Other"
        }
    }

    var proximityPromptTitle: String {
        switch self {
        case .home:
            return "Blisko domu"
        case .school:
            return "Blisko szkoły"
        case .work:
            return "Blisko pracy"
        case .doctor:
            return "Blisko wizyty"
        case .activity:
            return "Blisko aktywności"
        case .other:
            return "Blisko zapisanego miejsca"
        }
    }

    var arrivalMessagePrefix: String {
        switch self {
        case .home:
            return "dotarł(a) do domu"
        case .school:
            return "dotarł(a) do szkoły"
        case .work:
            return "dotarł(a) do pracy"
        case .doctor:
            return "dotarł(a) na wizytę"
        case .activity:
            return "dotarł(a) na aktywność"
        case .other:
            return "zrobił(a) check-in"
        }
    }
}

@Model
final class LocationCheckIn {
    @Attribute(.unique) var id: UUID
    var spaceId: UUID
    var userId: UUID
    var userDisplayName: String
    var placeId: UUID?
    var placeName: String?
    var latitude: Double
    var longitude: Double
    var note: String?
    var checkedInAt: Date
    var createdAt: Date
    var updatedAt: Date
    var version: Int
    var updatedBy: UUID?
    var deletedAt: Date?
    var pendingSync: Bool

    init(
        id: UUID = UUID(),
        spaceId: UUID,
        userId: UUID,
        userDisplayName: String,
        placeId: UUID? = nil,
        placeName: String? = nil,
        latitude: Double,
        longitude: Double,
        note: String? = nil,
        checkedInAt: Date = .now
    ) {
        self.id = id
        self.spaceId = spaceId
        self.userId = userId
        self.userDisplayName = userDisplayName
        self.placeId = placeId
        self.placeName = placeName
        self.latitude = latitude
        self.longitude = longitude
        self.note = note
        self.checkedInAt = checkedInAt
        self.createdAt = .now
        self.updatedAt = .now
        self.version = 1
        self.updatedBy = nil
        self.deletedAt = nil
        self.pendingSync = false
    }
}
