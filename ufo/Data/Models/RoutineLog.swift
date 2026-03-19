import Foundation
import SwiftData

@Model
final class RoutineLog {
    @Attribute(.unique) var id: UUID
    var routineId: UUID
    var spaceId: UUID
    var loggedAt: Date
    var createdAt: Date
    var updatedAt: Date
    var createdBy: UUID?
    var note: String?

    init(
        id: UUID = UUID(),
        routineId: UUID,
        spaceId: UUID,
        loggedAt: Date = .now,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        createdBy: UUID? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.routineId = routineId
        self.spaceId = spaceId
        self.loggedAt = loggedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
        self.note = note
    }
}
