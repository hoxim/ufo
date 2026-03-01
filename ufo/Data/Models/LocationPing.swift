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
