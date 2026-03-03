import Foundation
import SwiftData

@Model
final class NoteFolder {
    @Attribute(.unique) var id: UUID
    var spaceId: UUID
    var name: String
    var createdBy: UUID?
    var createdAt: Date
    var updatedAt: Date
    var version: Int
    var updatedBy: UUID?
    var deletedAt: Date?
    var pendingSync: Bool

    /// Creates folder model used to group notes in one space.
    init(
        id: UUID = UUID(),
        spaceId: UUID,
        name: String,
        createdBy: UUID? = nil
    ) {
        self.id = id
        self.spaceId = spaceId
        self.name = name
        self.createdBy = createdBy
        self.createdAt = .now
        self.updatedAt = .now
        self.version = 1
        self.updatedBy = nil
        self.deletedAt = nil
        self.pendingSync = false
    }
}
