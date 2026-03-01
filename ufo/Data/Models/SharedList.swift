import Foundation
import SwiftData

@Model
final class SharedList {
    @Attribute(.unique) var id: UUID
    var spaceId: UUID
    var name: String
    var type: String
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
        createdBy: UUID? = nil
    ) {
        self.id = id
        self.spaceId = spaceId
        self.name = name
        self.type = type
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
}
