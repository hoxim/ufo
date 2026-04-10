#if os(iOS)

import SwiftUI
import Charts


struct PadTodaySummaryCard: View {
    let widget: PadHomeWidgetState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider()
                .overlay(AppTheme.Colors.divider)

            VStack(alignment: .leading, spacing: 12) {
                PadHomeWidgetSectionHeader(
                    title: String(localized: "home.card.today.title"),
                    icon: "person.3.sequence.fill",
                    tint: AppTheme.FeatureColors.homeAccent
                )

                Text("home.card.today.description")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    summaryPill(title: String(localized: "home.card.today.dueMissions"), value: "\(widget.dueTodayCount)", tint: AppTheme.FeatureColors.missionsAccent)
                    summaryPill(title: String(localized: "home.card.today.recurring"), value: "\(widget.recurringMissionCount)", tint: AppTheme.FeatureColors.routinesAccent)
                    summaryPill(title: String(localized: "home.card.today.pinnedNotes"), value: "\(widget.pinnedNotesCount)", tint: AppTheme.FeatureColors.notesAccent)
                }

                HStack(spacing: 12) {
                    summaryPill(title: String(localized: "home.card.today.openIncidents"), value: "\(widget.openIncidentsCount)", tint: AppTheme.FeatureColors.incidentsAccent)
                    summaryPill(title: String(localized: "home.card.today.criticalAlerts"), value: "\(widget.criticalIncidentsCount)", tint: AppTheme.FeatureColors.notificationsAccent)
                    summaryPill(title: String(localized: "home.card.today.savedPlaces"), value: "\(widget.savedPlacesCount)", tint: AppTheme.FeatureColors.locationsAccent)
                }

                if let recentCheckInText = widget.recentCheckInText {
                    Label(String(format: String(localized: "home.card.today.lastCheckIn"), recentCheckInText), systemImage: "location.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("home.card.today.noCheckIns")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func summaryPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(tint)
            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppTheme.Colors.mutedFill, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct PadHomeBudgetCard: View {
    let entries: [BudgetEntry]
    @Binding var range: PadBudgetWidgetRange
    let onOpen: () -> Void

    private var filteredEntries: [BudgetEntry] {
        let start = Calendar.current.date(byAdding: .day, value: -(range.days - 1), to: Date()) ?? Date()
        return entries.filter { $0.entryDate >= start }
    }

    private var balance: Double {
        filteredEntries.reduce(0) { partial, entry in
            partial + (entry.kind == BudgetEntryKind.expense.rawValue ? -entry.amount : entry.amount)
        }
    }

    private var income: Double {
        filteredEntries
            .filter { $0.kind == BudgetEntryKind.income.rawValue }
            .reduce(0) { $0 + $1.amount }
    }

    private var expense: Double {
        filteredEntries
            .filter { $0.kind == BudgetEntryKind.expense.rawValue }
            .reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PadHomeWidgetSectionHeader(
                title: String(localized: "home.card.budget.title"),
                icon: "dollarsign.circle",
                tint: AppTheme.FeatureColors.budgetAccent,
                onOpen: onOpen
            )

            HStack(spacing: 8) {
                ForEach(PadBudgetWidgetRange.allCases, id: \.self) { option in
                    Button {
                        range = option
                    } label: {
                        Text(option.title)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(range == option ? AppTheme.FeatureColors.budgetAccent : AppTheme.Colors.mutedFill)
                            )
                            .foregroundStyle(range == option ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("home.card.budget.balance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(balance.formatted(.currency(code: "PLN")))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("home.card.budget.income")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(income.formatted(.currency(code: "PLN")))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("home.card.budget.expense")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(expense.formatted(.currency(code: "PLN")))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }

            if filteredEntries.isEmpty {
                Text("home.card.budget.empty")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Chart(filteredEntries.suffix(10)) { entry in
                    BarMark(
                        x: .value("Date", entry.entryDate, unit: .day),
                        y: .value("Amount", entry.kind == BudgetEntryKind.expense.rawValue ? -entry.amount : entry.amount)
                    )
                    .foregroundStyle(entry.kind == BudgetEntryKind.expense.rawValue ? .red : .green)
                }
                .frame(height: 140)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.Colors.card, in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            onOpen()
        }
    }
}

struct PadHomeWidgetSectionHeader: View {
    let title: String
    let icon: String
    let tint: Color
    var onOpen: (() -> Void)? = nil

    private var sectionForeground: Color {
        tint
    }

    private var chevronForeground: Color {
        Color.primary.opacity(0.72)
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(sectionForeground)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(sectionForeground)

            Spacer()

            if let onOpen {
                Button(action: onOpen) {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(chevronForeground)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct PadHomeMetricCard: View {
    let sectionTitle: String
    let sectionIcon: String
    let title: String
    let value: String
    let subtitle: String
    let tint: Color
    let span: HomeWidgetSpan

    private var sectionForeground: Color {
        Color.primary.opacity(0.92)
    }

    private var chevronForeground: Color {
        Color.primary.opacity(0.72)
    }

    private var cardHeight: CGFloat {
        span == .full ? 112 : 136
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: sectionIcon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(sectionForeground)

                Text(sectionTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(sectionForeground)

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(chevronForeground)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight, alignment: .topLeading)
        .padding(18)
        .background(AppTheme.Colors.card, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview("iPad Today Summary Card") {
    PadTodaySummaryCard(
        widget: PadHomeWidgetState(
            dueTodayCount: 4,
            recurringMissionCount: 2,
            pinnedNotesCount: 3,
            openIncidentsCount: 1,
            criticalIncidentsCount: 0,
            savedPlacesCount: 5,
            recentCheckInText: "Maria · School"
        )
    )
    .padding()
    .background(AppTheme.Colors.canvas)
}

#Preview("iPad Budget Card") {
    PadHomeBudgetCard(
        entries: padHomePreviewBudgetEntries(),
        range: .constant(.month),
        onOpen: {}
    )
    .padding()
    .background(AppTheme.Colors.canvas)
}

#Preview("iPad Metric Card") {
    PadHomeMetricCard(
        sectionTitle: String(localized: "home.hub.shortcut.missions.title"),
        sectionIcon: "target",
        title: String(localized: "home.hub.widget.nextMission.title"),
        value: "Doctor appointment",
        subtitle: String(localized: "home.hub.widget.nextMission.subtitle"),
        tint: AppTheme.FeatureColors.missionsAccent,
        span: .half
    )
    .padding()
    .background(AppTheme.Colors.canvas)
}

private func padHomePreviewBudgetEntries() -> [BudgetEntry] {
    let spaceID = UUID()
    return [
        BudgetEntry(spaceId: spaceID, title: "Salary", kind: BudgetEntryKind.income.rawValue, amount: 6200, category: "Work"),
        BudgetEntry(spaceId: spaceID, title: "Rent", kind: BudgetEntryKind.expense.rawValue, amount: 1800, category: "Home"),
        BudgetEntry(spaceId: spaceID, title: "Utilities", kind: BudgetEntryKind.expense.rawValue, amount: 320, category: "Home")
    ]
}


#endif
