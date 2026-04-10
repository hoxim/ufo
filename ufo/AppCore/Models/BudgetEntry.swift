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
    var subcategory: String?
    var merchantName: String?
    var merchantURLString: String?
    var iconName: String?
    var iconColorHex: String?
    var notes: String?
    var entryDate: Date
    var isFixed: Bool
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
        subcategory: String? = nil,
        merchantName: String? = nil,
        merchantURLString: String? = nil,
        iconName: String? = "dollarsign.circle",
        iconColorHex: String? = "#22C55E",
        notes: String? = nil,
        entryDate: Date = .now,
        isFixed: Bool = false,
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
        self.subcategory = subcategory
        self.merchantName = merchantName
        self.merchantURLString = merchantURLString
        self.iconName = iconName
        self.iconColorHex = iconColorHex
        self.notes = notes
        self.entryDate = entryDate
        self.isFixed = isFixed
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

    var transactionDate: Date {
        get { entryDate }
        set { entryDate = newValue }
    }

    var merchantURL: URL? {
        get {
            guard let merchantURLString, !merchantURLString.isEmpty else { return nil }
            return URL(string: merchantURLString)
        }
        set {
            merchantURLString = newValue?.absoluteString
        }
    }

    var signedAmount: Double {
        kind == BudgetEntryKind.expense.rawValue ? -amount : amount
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
