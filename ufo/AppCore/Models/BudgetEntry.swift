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
    var iconName: String?
    var iconColorHex: String?
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
        iconName: String? = "dollarsign.circle",
        iconColorHex: String? = "#22C55E",
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
        self.iconName = iconName
        self.iconColorHex = iconColorHex
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
        case .income: return String(localized: "budget.shared.kind.income")
        case .expense: return String(localized: "budget.shared.kind.expense")
        }
    }
}
