#if os(iOS)

import SwiftUI


enum PadBudgetKindFilter: String, CaseIterable {
    case all
    case income
    case expense

    var title: String {
        switch self {
        case .all: return "All"
        case .income: return "Income"
        case .expense: return "Expense"
        }
    }
}

enum PadBudgetRangeFilter: CaseIterable {
    case month
    case threeMonths
    case year
    case all

    var title: String {
        switch self {
        case .month: return "Month"
        case .threeMonths: return "3M"
        case .year: return "Year"
        case .all: return "All"
        }
    }

    var startDate: Date? {
        let calendar = Calendar.current
        switch self {
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: .now)
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: .now)
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: .now)
        case .all:
            return nil
        }
    }
}

enum PadBudgetRecurringInterval: String, CaseIterable {
    case weekly
    case monthly
    case yearly

    var title: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}

enum PadBudgetPresetCategory: CaseIterable {
    case home
    case food
    case subscriptions
    case transport
    case health
    case education
    case kids
    case entertainment
    case travel
    case pets
    case other

    var title: String {
        switch self {
        case .home: return "Home"
        case .food: return "Food"
        case .subscriptions: return "Subscriptions"
        case .transport: return "Transport"
        case .health: return "Health"
        case .education: return "Education"
        case .kids: return "Kids"
        case .entertainment: return "Entertainment"
        case .travel: return "Travel"
        case .pets: return "Pets"
        case .other: return "Other"
        }
    }
}

enum PadBudgetPresetIncomeCategory: CaseIterable {
    case salary
    case freelance
    case refund
    case gift
    case other

    var title: String {
        switch self {
        case .salary: return "Salary"
        case .freelance: return "Freelance"
        case .refund: return "Refund"
        case .gift: return "Gift"
        case .other: return "Other"
        }
    }
}

struct PadBudgetCategorySummary: Identifiable {
    let category: String
    let spent: Double
    let limit: Double?

    var id: String { category }

    var isOverLimit: Bool {
        guard let limit else { return false }
        return spent > limit
    }

    var progressValue: Double {
        guard let limit, limit > 0 else { return 0 }
        return min(spent / limit, 1)
    }

    var subtitle: String {
        if limit != nil {
            return "Spent vs limit"
        }
        return "No limit set yet"
    }

    var remainingText: String {
        guard let limit else { return "No limit" }
        let remaining = limit - spent
        if remaining >= 0 {
            return "\(remaining.formatted(.currency(code: "PLN"))) left"
        }
        return "\((-remaining).formatted(.currency(code: "PLN"))) over"
    }
}


#endif
