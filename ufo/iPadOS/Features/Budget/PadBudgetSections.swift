#if os(iOS)

import SwiftUI
import Charts

struct PadBudgetOverviewSection: View {
    let income: Double
    let expense: Double
    let balance: Double

    var body: some View {
        Section("budget.view.section.overview") {
            LabeledContent("budget.view.summary.income", value: income.formatted(.currency(code: "PLN")))
            LabeledContent("budget.view.summary.expense", value: expense.formatted(.currency(code: "PLN")))
            LabeledContent("budget.view.summary.balance", value: balance.formatted(.currency(code: "PLN")))
        }
    }
}

struct PadBudgetCashFlowSection: View {
    let entries: [BudgetEntry]

    var body: some View {
        Section("budget.view.section.cashFlow") {
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

struct PadBudgetCategoryBudgetsSection: View {
    let summaries: [PadBudgetCategorySummary]
    let onAddLimit: () -> Void
    let onEdit: (PadBudgetCategorySummary) -> Void
    let onDelete: (IndexSet) -> Void

    var body: some View {
        Section {
            ForEach(summaries) { summary in
                PadBudgetCategoryBudgetRow(summary: summary)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onEdit(summary)
                    }
            }
            .onDelete(perform: onDelete)
        } header: {
            HStack {
                Text("budget.view.section.categoryBudgets")
                Spacer()
                Button(action: onAddLimit) {
                    Label("budget.view.action.addLimit", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
        } footer: {
            Text("budget.view.description.categoryBudgets")
        }
    }
}

private struct PadBudgetCategoryBudgetRow: View {
    let summary: PadBudgetCategorySummary

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
                    Text(String(format: String(localized: "budget.view.label.limit"), limit.formatted(.currency(code: "PLN"))))
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

struct PadBudgetCustomCategoriesSection: View {
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
                Text("budget.view.section.customCategories")
                Spacer()
                Button(action: onAddCategory) {
                    Label("budget.view.action.addCategory", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
        } footer: {
            Text("budget.view.description.customCategories")
        }
    }
}

struct PadBudgetSubscriptionsSection: View {
    let entries: [BudgetEntry]

    var body: some View {
        Section("budget.view.section.subscriptions") {
            ForEach(entries) { entry in
                PadBudgetSubscriptionRow(entry: entry)
            }
        }
    }
}

private struct PadBudgetSubscriptionRow: View {
    let entry: BudgetEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.headline)
                Text("\(entry.category) · \(entry.recurringInterval ?? String(localized: "budget.view.subscription.recurring"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(entry.amount.formatted(.currency(code: "PLN")))
                .foregroundStyle(.red)
        }
    }
}

struct PadBudgetGoalsSection: View {
    let goals: [BudgetGoal]
    let onAddGoal: () -> Void

    var body: some View {
        Section {
            ForEach(goals) { goal in
                PadBudgetGoalRow(goal: goal)
            }
        } header: {
            HStack {
                Text("budget.view.section.goals")
                Spacer()
                Button(action: onAddGoal) {
                    Label("budget.view.action.addGoal", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

private struct PadBudgetGoalRow: View {
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

struct PadBudgetTransactionsSection: View {
    let entries: [BudgetEntry]
    let onDelete: (IndexSet) -> Void

    var body: some View {
        Section("budget.view.section.transactions") {
            ForEach(entries) { entry in
                PadBudgetTransactionRow(entry: entry)
            }
            .onDelete(perform: onDelete)
        }
    }
}

private struct PadBudgetTransactionRow: View {
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
