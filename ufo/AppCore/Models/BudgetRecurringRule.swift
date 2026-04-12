import Foundation
import SwiftData

enum BudgetRecurringCadence: String, CaseIterable, Codable, Identifiable {
    case daily
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily:   "Daily"
        case .weekly:  String(localized: "budget.recurring.weekly")
        case .monthly: String(localized: "budget.recurring.monthly")
        case .yearly:  String(localized: "budget.recurring.yearly")
        }
    }
}

@Model
final class BudgetRecurringRule {
    @Attribute(.unique) var id: UUID
    var spaceId: UUID
    var title: String
    var kind: BudgetEntryKind
    var amount: Double
    var category: String
    var subcategory: String?
    var merchantName: String?
    var merchantURLString: String?
    var notes: String?
    var cadence: BudgetRecurringCadence
    var anchorDate: Date
    var isFixed: Bool
    var iconName: String?
    var iconColorHex: String?
    var isActive: Bool
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
        kind: BudgetEntryKind,
        amount: Double,
        category: String,
        subcategory: String? = nil,
        merchantName: String? = nil,
        merchantURLString: String? = nil,
        notes: String? = nil,
        cadence: BudgetRecurringCadence,
        anchorDate: Date = .now,
        isFixed: Bool = true,
        iconName: String? = "arrow.triangle.2.circlepath.circle",
        iconColorHex: String? = "#9333EA",
        isActive: Bool = true,
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
        self.notes = notes
        self.cadence = cadence
        self.anchorDate = anchorDate
        self.isFixed = isFixed
        self.iconName = iconName
        self.iconColorHex = iconColorHex
        self.isActive = isActive
        self.createdBy = createdBy
        self.createdAt = .now
        self.updatedAt = .now
        self.version = 1
        self.updatedBy = nil
        self.deletedAt = nil
        self.pendingSync = false
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

    func nextOccurrence(after referenceDate: Date = .now, calendar: Calendar = .current) -> Date {
        var next = anchorDate
        guard next < referenceDate else { return next }

        let component: Calendar.Component = switch cadence {
        case .daily:   .day
        case .weekly:  .weekOfYear
        case .monthly: .month
        case .yearly:  .year
        }

        while next < referenceDate {
            guard let candidate = calendar.date(byAdding: component, value: 1, to: next) else { break }
            next = candidate
        }
        return next
    }
}
