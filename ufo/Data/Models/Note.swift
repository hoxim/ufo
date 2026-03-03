import Foundation
import SwiftData

@Model
final class Note {
    @Attribute(.unique) var id: UUID
    var spaceId: UUID
    var title: String
    var content: String
    var folderId: UUID?
    var attachedLinkURL: String?
    var relatedIncidentId: UUID?
    var relatedLocationLatitude: Double?
    var relatedLocationLongitude: Double?
    var relatedLocationLabel: String?
    var createdBy: UUID?
    var createdAt: Date
    var updatedAt: Date
    var version: Int
    var updatedBy: UUID?
    var deletedAt: Date?
    var pendingSync: Bool

    /// Creates note instance with optional attachments to link, incident and location.
    init(
        id: UUID = UUID(),
        spaceId: UUID,
        title: String,
        content: String,
        folderId: UUID? = nil,
        attachedLinkURL: String? = nil,
        relatedIncidentId: UUID? = nil,
        relatedLocationLatitude: Double? = nil,
        relatedLocationLongitude: Double? = nil,
        relatedLocationLabel: String? = nil,
        createdBy: UUID? = nil
    ) {
        self.id = id
        self.spaceId = spaceId
        self.title = title
        self.content = content
        self.folderId = folderId
        self.attachedLinkURL = attachedLinkURL
        self.relatedIncidentId = relatedIncidentId
        self.relatedLocationLatitude = relatedLocationLatitude
        self.relatedLocationLongitude = relatedLocationLongitude
        self.relatedLocationLabel = relatedLocationLabel
        self.createdBy = createdBy
        self.createdAt = .now
        self.updatedAt = .now
        self.version = 1
        self.updatedBy = nil
        self.deletedAt = nil
        self.pendingSync = false
    }
}
