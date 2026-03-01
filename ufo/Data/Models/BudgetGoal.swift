import Foundation
import SwiftData

@Model
final class BudgetGoal {
    @Attribute(.unique) var id: UUID
    var spaceId: UUID
    var title: String
    var targetAmount: Double
    var currentAmount: Double
    var dueDate: Date?
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
        title: String,
        targetAmount: Double,
        currentAmount: Double = 0,
        dueDate: Date? = nil,
        createdBy: UUID? = nil
    ) {
        self.id = id
        self.spaceId = spaceId
        self.title = title
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.dueDate = dueDate
        self.createdBy = createdBy
        self.createdAt = .now
        self.updatedAt = .now
        self.version = 1
        self.updatedBy = nil
        self.deletedAt = nil
        self.pendingSync = false
    }

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(max(currentAmount / targetAmount, 0), 1)
    }
}
