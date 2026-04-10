import Foundation

struct BudgetSummarySnapshot {
    let income: Double
    let expense: Double
    let net: Double
    let currentBalance: Double
}

struct BudgetCashFlowPoint: Identifiable {
    let date: Date
    let income: Double
    let expense: Double

    var id: Date { date }
}

struct BudgetRunningBalancePoint: Identifiable {
    let date: Date
    let balance: Double

    var id: Date { date }
}

struct BudgetCategoryBreakdownPoint: Identifiable {
    let category: String
    let amount: Double
    let limit: Double?

    var id: String { category }
}

struct BudgetUpcomingRecurringPoint: Identifiable {
    let rule: BudgetRecurringRule
    let nextDate: Date

    var id: UUID { rule.id }
}

struct BudgetAnalyticsService {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func summary(entries: [BudgetEntry], openingBalance: Double) -> BudgetSummarySnapshot {
        let income = entries.filter { $0.kind == BudgetEntryKind.income.rawValue }.reduce(0) { $0 + $1.amount }
        let expense = entries.filter { $0.kind == BudgetEntryKind.expense.rawValue }.reduce(0) { $0 + $1.amount }
        return BudgetSummarySnapshot(
            income: income,
            expense: expense,
            net: income - expense,
            currentBalance: openingBalance + income - expense
        )
    }

    func cashFlow(entries: [BudgetEntry], in interval: DateInterval, bucket: Calendar.Component = .day) -> [BudgetCashFlowPoint] {
        let filtered = entries.filter { interval.contains($0.transactionDate) }
        let grouped = Dictionary(grouping: filtered) { entry in
            calendar.startOfDay(for: entry.transactionDate)
        }

        var values: [BudgetCashFlowPoint] = []
        var cursor = calendar.startOfDay(for: interval.start)
        let end = interval.end

        while cursor <= end {
            let bucketEntries = grouped[cursor, default: []]
            values.append(
                BudgetCashFlowPoint(
                    date: cursor,
                    income: bucketEntries.filter { $0.kind == BudgetEntryKind.income.rawValue }.reduce(0) { $0 + $1.amount },
                    expense: bucketEntries.filter { $0.kind == BudgetEntryKind.expense.rawValue }.reduce(0) { $0 + $1.amount }
                )
            )
            guard let next = calendar.date(byAdding: bucket, value: 1, to: cursor) else { break }
            cursor = next
        }
        return values
    }

    func runningBalance(entries: [BudgetEntry], openingBalance: Double, in interval: DateInterval? = nil) -> [BudgetRunningBalancePoint] {
        let sorted = entries.sorted { $0.transactionDate < $1.transactionDate }
        var balance = openingBalance
        var points: [BudgetRunningBalancePoint] = []

        for entry in sorted {
            balance += entry.signedAmount
            if let interval, !interval.contains(entry.transactionDate) {
                continue
            }
            points.append(BudgetRunningBalancePoint(date: entry.transactionDate, balance: balance))
        }

        if points.isEmpty, let interval {
            points = [BudgetRunningBalancePoint(date: interval.start, balance: openingBalance)]
        }

        return points
    }

    func categoryBreakdown(entries: [BudgetEntry], limits: [String: Double]) -> [BudgetCategoryBreakdownPoint] {
        let expenses = entries.filter { $0.kind == BudgetEntryKind.expense.rawValue }
        let grouped = Dictionary(grouping: expenses, by: \.category)
        let categories = Set(grouped.keys).union(limits.keys)

        return categories
            .map { category in
                BudgetCategoryBreakdownPoint(
                    category: category,
                    amount: grouped[category, default: []].reduce(0) { $0 + $1.amount },
                    limit: limits[category]
                )
            }
            .sorted { $0.amount > $1.amount }
    }

    func upcomingRecurring(rules: [BudgetRecurringRule], from referenceDate: Date = .now, limit: Int = 5) -> [BudgetUpcomingRecurringPoint] {
        rules
            .filter { $0.deletedAt == nil && $0.isActive }
            .map { BudgetUpcomingRecurringPoint(rule: $0, nextDate: $0.nextOccurrence(after: referenceDate, calendar: calendar)) }
            .sorted { $0.nextDate < $1.nextDate }
            .prefix(limit)
            .map { $0 }
    }
}
