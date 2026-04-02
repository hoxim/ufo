#if os(macOS)

import SwiftUI
import Charts

struct MacBudgetOverviewSection: View {
    let income: Double
    let expense: Double
    let balance: Double

    var body: some View {
        Section("Overview") {
            LabeledContent("budget.view.summary.income", value: income.formatted(.currency(code: "PLN")))
            LabeledContent("budget.view.summary.expense", value: expense.formatted(.currency(code: "PLN")))
            LabeledContent("budget.view.summary.balance", value: balance.formatted(.currency(code: "PLN")))
        }
    }
}

struct MacBudgetCashFlowSection: View {
    let entries: [BudgetEntry]

    var body: some View {
        Section("Cash Flow") {
            Chart {
                ForEach(entries) { item in
                    LineMark(
                        x: .value("Date", item.entryDate),
                        y: .value("Amount", item.kind == BudgetEntryKind.expense.rawValue ? -item.amount : item.amount)
                    )
                    .foregroundStyle(item.kind == BudgetEntryKind.expense.rawValue ? .red : .green)
                }
            }
            .frame(height: 220)
        }
    }
}

struct MacBudgetCategoryBudgetsSection: View {
    let summaries: [MacBudgetCategorySummary]
    let onAddLimit: () -> Void
    let onEdit: (MacBudgetCategorySummary) -> Void
    let onDelete: (IndexSet) -> Void

    var body: some View {
        Section {
            ForEach(summaries) { summary in
                MacBudgetCategoryBudgetRow(summary: summary)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onEdit(summary)
                    }
            }
            .onDelete(perform: onDelete)
        } header: {
            HStack {
                Text("Category Budgets")
                Spacer()
                Button(action: onAddLimit) {
                    Label("Add Limit", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
        } footer: {
            Text("Set monthly limits for categories like Home, Food or Subscriptions, and compare them with the current spend.")
        }
    }
}

private struct MacBudgetCategoryBudgetRow: View {
    let summary: MacBudgetCategorySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.category)
                        .font(.headline)
                    Text(summary.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(summary.spent.formatted(.currency(code: "PLN")))
                    .font(.headline)
                    .foregroundStyle(summary.isOverLimit ? .red : .primary)
            }

            if let limit = summary.limit {
                ProgressView(value: summary.progressValue)
                    .tint(summary.isOverLimit ? .red : .accentColor)
                HStack {
                    Text("Limit \(limit.formatted(.currency(code: "PLN")))")
                    Spacer()
                    Text(summary.remainingText)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MacBudgetCustomCategoriesSection: View {
    let categories: [String]
    let onAddCategory: () -> Void
    let onDelete: (IndexSet) -> Void

    var body: some View {
        Section {
            ForEach(categories, id: \.self) { category in
                Text(category)
            }
            .onDelete(perform: onDelete)
        } header: {
            HStack {
                Text("Custom Categories")
                Spacer()
                Button(action: onAddCategory) {
                    Label("Add Category", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
        } footer: {
            Text("Custom categories are available in the transaction form and can also have their own monthly limits.")
        }
    }
}

struct MacBudgetSubscriptionsSection: View {
    let entries: [BudgetEntry]

    var body: some View {
        Section("Subscriptions") {
            ForEach(entries) { entry in
                MacBudgetSubscriptionRow(entry: entry)
            }
        }
    }
}

private struct MacBudgetSubscriptionRow: View {
    let entry: BudgetEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.headline)
                Text("\(entry.category) · \(entry.recurringInterval ?? "Recurring")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(entry.amount.formatted(.currency(code: "PLN")))
                .foregroundStyle(.red)
        }
    }
}

struct MacBudgetGoalsSection: View {
    let goals: [BudgetGoal]
    let onAddGoal: () -> Void

    var body: some View {
        Section {
            ForEach(goals) { goal in
                MacBudgetGoalRow(goal: goal)
            }
        } header: {
            HStack {
                Text("Goals")
                Spacer()
                Button(action: onAddGoal) {
                    Label("Add Goal", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

private struct MacBudgetGoalRow: View {
    let goal: BudgetGoal

    var body: some View {
        VStack(alignment: .leading) {
            Text(goal.title)
                .font(.headline)
            ProgressView(value: goal.progress)
            Text("\(goal.currentAmount.formatted(.currency(code: "PLN"))) / \(goal.targetAmount.formatted(.currency(code: "PLN")))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct MacBudgetTransactionsSection: View {
    let entries: [BudgetEntry]
    let onDelete: (IndexSet) -> Void

    var body: some View {
        Section("Transactions") {
            ForEach(entries) { entry in
                MacBudgetTransactionRow(entry: entry)
            }
            .onDelete(perform: onDelete)
        }
    }
}

private struct MacBudgetTransactionRow: View {
    let entry: BudgetEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    if let icon = entry.iconName {
                        Image(systemName: icon)
                            .foregroundStyle(Color(hex: entry.iconColorHex ?? "#22C55E"))
                    }
                    Text(entry.title)
                        .font(.headline)
                }
                Text(entry.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text((entry.kind == BudgetEntryKind.expense.rawValue ? -entry.amount : entry.amount).formatted(.currency(code: "PLN")))
                .foregroundStyle(entry.kind == BudgetEntryKind.expense.rawValue ? .red : .green)
        }
    }
}

#endif
