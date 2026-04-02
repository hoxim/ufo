import Foundation
import SwiftData
import SwiftUI

@Model
final class Note {
    @Attribute(.unique) var id: UUID
    var spaceId: UUID
    var title: String
    var content: String
    var folderId: UUID?
    var attachedLinkURL: String?
    var tags: [String]?
    var isPinned: Bool?
    var linkedEntityType: String?
    var linkedEntityId: UUID?
    var savedPlaceId: UUID?
    var savedPlaceName: String?
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
        tags: [String] = [],
        isPinned: Bool = false,
        linkedEntityType: String? = nil,
        linkedEntityId: UUID? = nil,
        savedPlaceId: UUID? = nil,
        savedPlaceName: String? = nil,
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
        self.tags = tags
        self.isPinned = isPinned
        self.linkedEntityType = linkedEntityType
        self.linkedEntityId = linkedEntityId
        self.savedPlaceId = savedPlaceId
        self.savedPlaceName = savedPlaceName
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

extension Note {
    var resolvedTags: [String] {
        tags ?? []
    }

    var isPinnedValue: Bool {
        isPinned ?? false
    }

    var renderedContent: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let value = try? AttributedString(markdown: content, options: options) {
            return value
        }
        return AttributedString(content)
    }

    var previewText: String {
        content
            .replacingOccurrences(of: #"(?m)^#{1,6}\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^>\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^-\s\[[ xX]\]\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^[-*]\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[*_`]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum NoteLinkedEntityType: String, CaseIterable, Identifiable {
    case mission
    case incident
    case place
    case person

    var id: String { rawValue }

    var localizedLabel: String {
        switch self {
        case .mission:
            return "Mission"
        case .incident:
            return "Incident"
        case .place:
            return "Place"
        case .person:
            return "Person"
        }
    }
}
