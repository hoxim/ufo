import Foundation
import SwiftData

@Model
final class BudgetEntry {
    @Attribute(.unique) var id: UUID
    var spaceId: UUID
    var title: String
    var kind: String
    var amount: Double
    var category: String
    var notes: String?
    var entryDate: Date
    var isRecurring: Bool
    var recurringInterval: String?
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
        kind: String,
        amount: Double,
        category: String = "General",
        notes: String? = nil,
        entryDate: Date = .now,
        isRecurring: Bool = false,
        recurringInterval: String? = nil,
        createdBy: UUID? = nil
    ) {
        self.id = id
        self.spaceId = spaceId
        self.title = title
        self.kind = kind
        self.amount = amount
        self.category = category
        self.notes = notes
        self.entryDate = entryDate
        self.isRecurring = isRecurring
        self.recurringInterval = recurringInterval
        self.createdBy = createdBy
        self.createdAt = .now
        self.updatedAt = .now
        self.version = 1
        self.updatedBy = nil
        self.deletedAt = nil
        self.pendingSync = false
    }
}

enum BudgetEntryKind: String, CaseIterable, Identifiable {
    case income = "income"
    case expense = "expense"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .income: return "Income"
        case .expense: return "Expense"
        }
    }
}
