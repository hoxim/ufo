import Foundation
import SwiftData

@Model
final class SharedListItem {
    @Attribute(.unique) var id: UUID
    var listId: UUID
    var title: String
    var isCompleted: Bool
    var position: Int
    var createdAt: Date
    var updatedAt: Date
    var version: Int
    var updatedBy: UUID?
    var deletedAt: Date?
    var pendingSync: Bool

    init(
        id: UUID = UUID(),
        listId: UUID,
        title: String,
        isCompleted: Bool = false,
        position: Int = 0
    ) {
        self.id = id
        self.listId = listId
        self.title = title
        self.isCompleted = isCompleted
        self.position = position
        self.createdAt = .now
        self.updatedAt = .now
        self.version = 1
        self.updatedBy = nil
        self.deletedAt = nil
        self.pendingSync = false
    }
}
