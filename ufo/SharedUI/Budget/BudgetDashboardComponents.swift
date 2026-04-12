import SwiftUI
import Charts

struct BudgetDashboardRow: Identifiable {
    enum Style {
        case single
        case pair
    }

    let widgets: [BudgetDashboardWidgetPreference]
    let style: Style
    let id = UUID()
}

enum BudgetDashboardDetailKind: String, Identifiable {
    case cashFlow
    case runningBalance
    case categories
    case recurring

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cashFlow: "Cash flow"
        case .runningBalance: "Running balance"
        case .categories: "Categories"
        case .recurring: "Upcoming recurring"
        }
    }
}

func budgetDashboardRows(from preferences: [BudgetDashboardWidgetPreference]) -> [BudgetDashboardRow] {
    var rows: [BudgetDashboardRow] = []
    var halfRow: [BudgetDashboardWidgetPreference] = []

    for preference in preferences where preference.isVisible {
        if preference.span == .full {
            if !halfRow.isEmpty {
                rows.append(BudgetDashboardRow(widgets: halfRow, style: .pair))
                halfRow.removeAll()
            }
            rows.append(BudgetDashboardRow(widgets: [preference], style: .single))
        } else {
            halfRow.append(preference)
            if halfRow.count == 2 {
                rows.append(BudgetDashboardRow(widgets: halfRow, style: .pair))
                halfRow.removeAll()
            }
        }
    }

    if !halfRow.isEmpty {
        rows.append(BudgetDashboardRow(widgets: halfRow, style: .pair))
    }

    return rows
}

struct BudgetDashboardCustomizationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences
    let title: String

    var body: some View {
        @Bindable var appPreferences = appPreferences

        NavigationStack {
            List {
                Section {
                    Text("Choose which budget insights appear on the main dashboard and how large they should be.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Widgets") {
                    ForEach($appPreferences.budgetDashboardWidgets) { $preference in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Label(preference.kind.title, systemImage: preference.kind.systemImage)
                                    .font(.body.weight(.semibold))

                                Spacer()

                                Button {
                                    preference.isVisible.toggle()
                                } label: {
                                    Image(systemName: preference.isVisible ? "minus.circle.fill" : "plus.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(preference.isVisible ? .red : .green)
                                }
                                .buttonStyle(.plain)
                            }

                            if preference.kind.supportedSpans.count > 1 {
                                Picker("Size", selection: $preference.span) {
                                    ForEach(preference.kind.supportedSpans) { span in
                                        Text(span.title).tag(span)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove { fromOffsets, toOffset in
                        appPreferences.budgetDashboardWidgets.move(fromOffsets: fromOffsets, toOffset: toOffset)
                    }
                }
            }
            .activeEditModeIfSupported(true)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct BudgetDashboardCard<Content: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    let secondaryActionTitle: String?
    let secondaryAction: (() -> Void)?
    @ViewBuilder let content: Content

    init(
        title: String,
        systemImage: String,
        tint: Color,
        secondaryActionTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.secondaryActionTitle = secondaryActionTitle
        self.secondaryAction = secondaryAction
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                if let secondaryActionTitle, let secondaryAction {
                    Button(secondaryActionTitle, action: secondaryAction)
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(tint)
                }
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(0.14), lineWidth: 1)
        )
    }
}

struct BudgetOverviewDashboardCard: View {
    let snapshot: BudgetSummarySnapshot
    let currencyCode: String

    var body: some View {
        BudgetDashboardCard(
            title: "Overview",
            systemImage: "chart.bar.doc.horizontal",
            tint: AppTheme.FeatureColors.budgetAccent
        ) {
            HStack(spacing: 12) {
                BudgetMetricPill(title: "Income", value: snapshot.income, currencyCode: currencyCode, tint: AppTheme.ChartColors.income)
                BudgetMetricPill(title: "Expense", value: snapshot.expense, currencyCode: currencyCode, tint: AppTheme.ChartColors.expense)
                BudgetMetricPill(title: "Balance", value: snapshot.currentBalance, currencyCode: currencyCode, tint: AppTheme.ChartColors.balance)
            }
        }
    }
}

struct BudgetCashFlowDashboardCard: View {
    let points: [BudgetCashFlowPoint]
    let currencyCode: String
    let onMore: (() -> Void)?

    var body: some View {
        BudgetDashboardCard(
            title: "Cash flow",
            systemImage: "chart.bar.xaxis",
            tint: AppTheme.ChartColors.balance,
            secondaryActionTitle: onMore == nil ? nil : "More",
            secondaryAction: onMore
        ) {
            if points.isEmpty {
                BudgetEmptyCardBody(title: "No transactions in this range yet.")
            } else {
                Chart {
                    ForEach(points) { point in
                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Income", point.income)
                        )
                        .foregroundStyle(AppTheme.ChartColors.income)

                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Expense", -point.expense)
                        )
                        .foregroundStyle(AppTheme.ChartColors.expense)
                    }
                }
                .frame(height: 190)

                HStack {
                    Text("Positive values show income, negative values show expenses.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(totalNet(points).formatted(.currency(code: currencyCode)))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    private func totalNet(_ points: [BudgetCashFlowPoint]) -> Double {
        points.reduce(0) { $0 + $1.income - $1.expense }
    }
}

struct BudgetRunningBalanceDashboardCard: View {
    let points: [BudgetRunningBalancePoint]
    let currencyCode: String
    let onMore: (() -> Void)?

    var body: some View {
        BudgetDashboardCard(
            title: "Running balance",
            systemImage: "chart.line.uptrend.xyaxis",
            tint: AppTheme.ChartColors.balance,
            secondaryActionTitle: onMore == nil ? nil : "More",
            secondaryAction: onMore
        ) {
            if points.isEmpty {
                BudgetEmptyCardBody(title: "Add transactions to build your balance history.")
            } else {
                Chart(points) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Balance", point.balance)
                    )
                    .foregroundStyle(AppTheme.ChartColors.balance)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Balance", point.balance)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.ChartColors.balance.opacity(0.22), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .frame(height: 190)

                if let lastPoint = points.last {
                    Text("Current balance: \(lastPoint.balance.formatted(.currency(code: currencyCode)))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct BudgetCategoryBreakdownDashboardCard: View {
    let points: [BudgetCategoryBreakdownPoint]
    let currencyCode: String
    let onMore: (() -> Void)?

    var body: some View {
        BudgetDashboardCard(
            title: "Categories",
            systemImage: "chart.pie",
            tint: AppTheme.FeatureColors.budgetAccent,
            secondaryActionTitle: onMore == nil ? nil : "More",
            secondaryAction: onMore
        ) {
            if points.isEmpty {
                BudgetEmptyCardBody(title: "No category spending in this range.")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Chart(Array(points.prefix(5).enumerated()), id: \.element.id) { index, point in
                        SectorMark(
                            angle: .value("Amount", max(point.amount, 0.01)),
                            innerRadius: .ratio(0.52),
                            angularInset: 1.5
                        )
                        .foregroundStyle(AppTheme.ChartColors.categorySeries[index % AppTheme.ChartColors.categorySeries.count])
                    }
                    .frame(height: 180)

                    ForEach(Array(points.prefix(3))) { point in
                        HStack {
                            Text(point.category)
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text(point.amount.formatted(.currency(code: currencyCode)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

struct BudgetUpcomingRecurringDashboardCard: View {
    let items: [BudgetUpcomingRecurringPoint]
    let currencyCode: String
    let onMore: (() -> Void)?

    var body: some View {
        BudgetDashboardCard(
            title: "Upcoming recurring",
            systemImage: "calendar.badge.clock",
            tint: AppTheme.FeatureColors.budgetAccent,
            secondaryActionTitle: onMore == nil ? nil : "More",
            secondaryAction: onMore
        ) {
            if items.isEmpty {
                BudgetEmptyCardBody(title: "No recurring rules yet.")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(items.prefix(4)) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(item.rule.kind == .expense ? AppTheme.ChartColors.expense : AppTheme.ChartColors.income)
                                .frame(width: 10, height: 10)
                                .padding(.top, 5)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.rule.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(item.nextDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(item.rule.amount.formatted(.currency(code: currencyCode)))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(item.rule.kind == .expense ? AppTheme.ChartColors.expense : AppTheme.ChartColors.income)
                        }
                    }
                }
            }
        }
    }
}

struct BudgetDashboardDetailView: View {
    let kind: BudgetDashboardDetailKind
    let cashFlow: [BudgetCashFlowPoint]
    let runningBalance: [BudgetRunningBalancePoint]
    let categories: [BudgetCategoryBreakdownPoint]
    let recurring: [BudgetUpcomingRecurringPoint]
    let currencyCode: String

    var body: some View {
        List {
            switch kind {
            case .cashFlow:
                Section("Daily cash flow") {
                    BudgetCashFlowDashboardCard(points: cashFlow, currencyCode: currencyCode, onMore: nil)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            case .runningBalance:
                Section("Balance history") {
                    BudgetRunningBalanceDashboardCard(points: runningBalance, currencyCode: currencyCode, onMore: nil)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            case .categories:
                Section("Category breakdown") {
                    BudgetCategoryBreakdownDashboardCard(points: categories, currencyCode: currencyCode, onMore: nil)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                if !categories.isEmpty {
                    Section("All categories") {
                        ForEach(categories) { point in
                            HStack {
                                Text(point.category)
                                Spacer()
                                if let limit = point.limit {
                                    Text("\(point.amount.formatted(.currency(code: currencyCode))) / \(limit.formatted(.currency(code: currencyCode)))")
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(point.amount.formatted(.currency(code: currencyCode)))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            case .recurring:
                Section("Upcoming recurring") {
                    BudgetUpcomingRecurringDashboardCard(items: recurring, currencyCode: currencyCode, onMore: nil)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                if !recurring.isEmpty {
                    Section("Schedule") {
                        ForEach(recurring) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.rule.title)
                                    .font(.headline)
                                Text("\(item.rule.cadence.displayName) • \(item.nextDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(kind.title)
        .appScreenBackground()
    }
}

struct BudgetSpaceSettingsEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let store: BudgetStore
    let actor: UUID?
    let initialOpeningBalance: Double
    let initialCurrencyCode: String

    @State private var openingBalanceText: String
    @State private var currency: AppCurrencyPreference
    @State private var isSaving = false

    init(
        store: BudgetStore,
        actor: UUID?,
        initialOpeningBalance: Double,
        initialCurrencyCode: String
    ) {
        self.store = store
        self.actor = actor
        self.initialOpeningBalance = initialOpeningBalance
        self.initialCurrencyCode = initialCurrencyCode
        _openingBalanceText = State(initialValue: initialOpeningBalance == 0 ? "" : String(format: "%.2f", initialOpeningBalance).replacingOccurrences(of: ".", with: ","))
        _currency = State(initialValue: AppCurrencyPreference(rawValue: initialCurrencyCode.uppercased()) ?? .pln)
    }

    var body: some View {
        AdaptiveFormContent {
            Form {
                TextField("Opening balance", text: $openingBalanceText)
                    .prominentFormTextInput()
                    .decimalPadKeyboardIfSupported()

                Picker("settings.localization.currency", selection: $currency) {
                    ForEach(AppCurrencyPreference.allCases) { currency in
                        Text(currency.title).tag(currency)
                    }
                }
            }
            .navigationTitle("Budget settings")
            .modalInlineTitleDisplayMode()
            .toolbar {
                ModalCloseToolbarItem {
                    dismiss()
                }
                ModalConfirmToolbarItem(
                    isDisabled: isSaving,
                    isProcessing: isSaving,
                    action: { Task { await save() } }
                )
            }
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let openingBalance = Double(openingBalanceText.replacingOccurrences(of: ",", with: ".")) ?? 0
        await store.updateSpaceSettings(
            openingBalance: openingBalance,
            currencyCode: currency.currencyCode,
            actor: actor
        )
        dismiss()
    }
}

private struct BudgetMetricPill: View {
    let title: String
    let value: Double
    let currencyCode: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)

            Text(value.formatted(.currency(code: currencyCode)))
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct BudgetEmptyCardBody: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 24)
    }
}
