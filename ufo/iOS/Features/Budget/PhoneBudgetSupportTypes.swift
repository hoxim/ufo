#if os(iOS)

import SwiftUI


enum PhoneBudgetKindFilter: String, CaseIterable {
    case all
    case income
    case expense

    var title: String {
        switch self {
        case .all: return String(localized: "budget.filter.option.all")
        case .income: return String(localized: "budget.shared.kind.income")
        case .expense: return String(localized: "budget.shared.kind.expense")
        }
    }
}

enum PhoneBudgetRangeFilter: CaseIterable {
    case month
    case threeMonths
    case year
    case all

    var title: String {
        switch self {
        case .month: return String(localized: "budget.filter.range.month")
        case .threeMonths: return "3M"
        case .year: return String(localized: "budget.filter.range.year")
        case .all: return String(localized: "budget.filter.option.all")
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

enum PhoneBudgetRecurringInterval: String, CaseIterable {
    case weekly
    case monthly
    case yearly

    var title: String {
        switch self {
        case .weekly: return String(localized: "budget.recurring.weekly")
        case .monthly: return String(localized: "budget.recurring.monthly")
        case .yearly: return String(localized: "budget.recurring.yearly")
        }
    }
}

enum PhoneBudgetPresetCategory: CaseIterable {
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
        case .home: return String(localized: "budget.category.home")
        case .food: return String(localized: "budget.category.food")
        case .subscriptions: return String(localized: "budget.view.section.subscriptions")
        case .transport: return String(localized: "budget.category.transport")
        case .health: return String(localized: "budget.category.health")
        case .education: return String(localized: "budget.category.education")
        case .kids: return String(localized: "budget.category.kids")
        case .entertainment: return String(localized: "budget.category.entertainment")
        case .travel: return String(localized: "budget.category.travel")
        case .pets: return String(localized: "budget.category.pets")
        case .other: return String(localized: "budget.filter.option.other")
        }
    }
}

enum PhoneBudgetPresetIncomeCategory: CaseIterable {
    case salary
    case freelance
    case refund
    case gift
    case other

    var title: String {
        switch self {
        case .salary: return String(localized: "budget.income.salary")
        case .freelance: return String(localized: "budget.income.freelance")
        case .refund: return String(localized: "budget.income.refund")
        case .gift: return String(localized: "budget.income.gift")
        case .other: return String(localized: "budget.filter.option.other")
        }
    }
}

struct PhoneBudgetCategorySummary: Identifiable {
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
            return String(localized: "budget.summary.spentVsLimit")
        }
        return String(localized: "budget.summary.noLimitSet")
    }

    var remainingText: String {
        guard let limit else { return String(localized: "budget.summary.noLimit") }
        let remaining = limit - spent
        if remaining >= 0 {
            return String(format: String(localized: "budget.summary.left"), remaining.formatted(.currency(code: "PLN")))
        }
        return String(format: String(localized: "budget.summary.over"), (-remaining).formatted(.currency(code: "PLN")))
    }
}


#endif
