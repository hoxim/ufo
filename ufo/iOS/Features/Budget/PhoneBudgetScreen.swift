#if os(iOS)

import SwiftUI
import SwiftData

struct PhoneBudgetScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo
    @Environment(AppPreferences.self) private var appPreferences

    @State private var budgetStore: BudgetStore?
    @State private var showAddEntry = false
    @State private var showAddGoal = false
    @State private var showAddCategoryBudget = false
    @State private var showAddCustomCategory = false
    @State private var showDashboardCustomize = false
    @State private var showBudgetSettings = false
    @State private var selectedDetail: BudgetDashboardDetailKind?
    @State private var editingCategoryBudget: BudgetCategoryLimitPreference?
    @State private var didAutoPresentAddEntry = false
    @State private var selectedKindFilter: PhoneBudgetKindFilter = .all
    @State private var selectedRangeFilter: PhoneBudgetRangeFilter = .month
    @State private var selectedCategoryFilter = String(localized: "budget.filter.option.all")
    @State private var searchText = ""

    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    let autoPresentAddEntry: Bool

    init(autoPresentAddEntry: Bool = false) {
        self.autoPresentAddEntry = autoPresentAddEntry
    }

    var body: some View {
        contentList
            .navigationTitle("budget.view.title")
            .hideTabBarIfSupported()
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        filterMenuContent
                    } label: {
                        Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }

                    Menu {
                        Button("Customize dashboard") {
                            showDashboardCustomize = true
                        }

                        Button("Budget settings") {
                            showBudgetSettings = true
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }

                    Button {
                        showAddEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await refreshBudget()
            }
            .adaptiveFormPresentation(isPresented: $showAddEntry) {
                if let budgetStore {
                    PhoneAddBudgetEntryView(
                        store: budgetStore,
                        actor: authRepo.currentUser?.id,
                        customCategories: appPreferences.budgetCustomCategories
                    )
                    .presentationDetents([.medium, .large])
                }
            }
            .adaptiveFormPresentation(isPresented: $showAddGoal) {
                if let budgetStore {
                    PhoneAddBudgetGoalView(store: budgetStore, actor: authRepo.currentUser?.id)
                        .presentationDetents([.medium, .large])
                }
            }
            .adaptiveFormPresentation(isPresented: $showAddCategoryBudget) {
                PhoneAddCategoryBudgetView(
                    initialCategory: nil,
                    initialAmount: nil,
                    customCategories: appPreferences.budgetCustomCategories,
                    existingCategories: availableCategories
                ) { category, amount in
                    appPreferences.setBudgetCategoryLimit(category: category, amount: amount)
                } onAddCategory: { value in
                    appPreferences.addBudgetCustomCategory(value)
                }
                .presentationDetents([.medium, .large])
            }
            .adaptiveFormPresentation(item: $editingCategoryBudget) { categoryBudget in
                PhoneAddCategoryBudgetView(
                    initialCategory: categoryBudget.category,
                    initialAmount: categoryBudget.amount,
                    customCategories: appPreferences.budgetCustomCategories,
                    existingCategories: availableCategories
                ) { category, amount in
                    appPreferences.setBudgetCategoryLimit(category: category, amount: amount)
                } onAddCategory: { value in
                    appPreferences.addBudgetCustomCategory(value)
                }
                .presentationDetents([.medium, .large])
            }
            .adaptiveFormPresentation(isPresented: $showAddCustomCategory) {
                PhoneAddCustomBudgetCategoryView { value in
                    appPreferences.addBudgetCustomCategory(value)
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showDashboardCustomize) {
                BudgetDashboardCustomizationView(title: "Customize budget dashboard")
                    .environment(appPreferences)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showBudgetSettings) {
                if let budgetStore {
                    BudgetSpaceSettingsEditorView(
                        store: budgetStore,
                        actor: authRepo.currentUser?.id,
                        initialOpeningBalance: budgetStore.openingBalance,
                        initialCurrencyCode: budgetStore.currencyCode
                    )
                    .presentationDetents([.medium])
                }
            }
            .sheet(item: $selectedDetail) { detail in
                NavigationStack {
                    BudgetDashboardDetailView(
                        kind: detail,
                        cashFlow: cashFlowPoints,
                        runningBalance: runningBalancePoints,
                        categories: categoryBreakdownPoints,
                        recurring: upcomingRecurringPoints,
                        currencyCode: budgetCurrencyCode
                    )
                }
            }
            .task {
                await setupStoreIfNeeded(performRemoteRefresh: !autoPresentAddEntry)
                if autoPresentAddEntry && !didAutoPresentAddEntry && budgetStore != nil {
                    didAutoPresentAddEntry = true
                    try? await Task.sleep(for: .milliseconds(300))
                    showAddEntry = true
                }
            }
            .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
                budgetStore?.setSpace(newValue)
                Task { await budgetStore?.refreshRemote() }
            }
            .safeAreaInset(edge: .bottom) {
                FeatureBottomSearchBar(text: $searchText, prompt: "budget.search.prompt")
            }
    }

    private var contentList: some View {
        List {
            if let error = budgetStore?.lastErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            dashboardSection

            PhoneBudgetGoalsSection(
                goals: filteredGoals,
                onAddGoal: { showAddGoal = true }
            )

            PhoneBudgetCategoryBudgetsSection(
                summaries: categorySummaries,
                onAddLimit: { showAddCategoryBudget = true },
                onEdit: { summary in
                    editingCategoryBudget = BudgetCategoryLimitPreference(category: summary.category, amount: summary.limit ?? 0)
                },
                onDelete: { offsets in
                    for index in offsets {
                        appPreferences.removeBudgetCategoryLimit(category: categorySummaries[index].category)
                    }
                }
            )

            PhoneBudgetCustomCategoriesSection(
                categories: appPreferences.budgetCustomCategories,
                onAddCategory: { showAddCustomCategory = true },
                onDelete: { offsets in
                    for index in offsets {
                        appPreferences.removeBudgetCustomCategory(appPreferences.budgetCustomCategories[index])
                    }
                }
            )

            PhoneBudgetTransactionsSection(
                entries: recentTransactions,
                onDelete: { offsets in
                    guard let store = budgetStore else { return }
                    let values = offsets.map { recentTransactions[$0] }
                    Task {
                        for entry in values {
                            await store.deleteEntry(entry, actor: authRepo.currentUser?.id)
                        }
                    }
                }
            )
        }
        .appPrimaryListChrome()
    }

    private var dashboardSection: some View {
        Section {
            ForEach(widgetRows) { row in
                dashboardRow(row)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
    }

    @ViewBuilder
    private func dashboardRow(_ row: BudgetDashboardRow) -> some View {
        switch row.style {
        case .single:
            if let widget = row.widgets.first {
                dashboardWidgetView(widget)
            }
        case .pair:
            HStack(alignment: .top, spacing: 12) {
                if let first = row.widgets.first {
                    dashboardWidgetView(first)
                }

                if row.widgets.count > 1, let second = row.widgets.last {
                    dashboardWidgetView(second)
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity, minHeight: 1)
                }
            }
        }
    }

    @ViewBuilder
    private func dashboardWidgetView(_ preference: BudgetDashboardWidgetPreference) -> some View {
        switch preference.kind {
        case .overview:
            BudgetOverviewDashboardCard(snapshot: summarySnapshot, currencyCode: budgetCurrencyCode)
        case .cashFlow:
            BudgetCashFlowDashboardCard(points: cashFlowPoints, currencyCode: budgetCurrencyCode) {
                selectedDetail = .cashFlow
            }
        case .runningBalance:
            BudgetRunningBalanceDashboardCard(points: runningBalancePoints, currencyCode: budgetCurrencyCode) {
                selectedDetail = .runningBalance
            }
        case .categoryBreakdown:
            BudgetCategoryBreakdownDashboardCard(points: categoryBreakdownPoints, currencyCode: budgetCurrencyCode) {
                selectedDetail = .categories
            }
        case .upcomingRecurring:
            BudgetUpcomingRecurringDashboardCard(items: upcomingRecurringPoints, currencyCode: budgetCurrencyCode) {
                selectedDetail = .recurring
            }
        }
    }

    @ViewBuilder
    private var filterMenuContent: some View {
        Section("budget.filter.section.period") {
            ForEach(PhoneBudgetRangeFilter.allCases, id: \.self) { filter in
                Button {
                    selectedRangeFilter = filter
                } label: {
                    filterMenuLabel(title: filter.title, isSelected: selectedRangeFilter == filter)
                }
            }
        }

        Section("budget.filter.section.type") {
            ForEach(PhoneBudgetKindFilter.allCases, id: \.self) { filter in
                Button {
                    selectedKindFilter = filter
                } label: {
                    filterMenuLabel(title: filter.title, isSelected: selectedKindFilter == filter)
                }
            }
        }

        Section("budget.filter.section.category") {
            Button {
                selectedCategoryFilter = String(localized: "budget.filter.option.all")
            } label: {
                filterMenuLabel(
                    title: String(localized: "budget.filter.option.all"),
                    isSelected: selectedCategoryFilter == String(localized: "budget.filter.option.all")
                )
            }

            ForEach(availableCategories, id: \.self) { category in
                Button {
                    selectedCategoryFilter = category
                } label: {
                    filterMenuLabel(title: category, isSelected: selectedCategoryFilter == category)
                }
            }
        }

        if hasActiveFilters {
            Divider()

            Button("budget.filter.action.reset") {
                resetFilters()
            }
        }
    }

    private var widgetRows: [BudgetDashboardRow] {
        budgetDashboardRows(from: appPreferences.budgetDashboardWidgets)
    }

    private var availableCategories: [String] {
        let entryCategories = budgetStore?.entries.map(\.category) ?? []
        let ruleCategories = budgetStore?.recurringRules.map(\.category) ?? []
        let values = Set(PhoneBudgetPresetCategory.allCases.map(\.title) + appPreferences.budgetCustomCategories + entryCategories + ruleCategories)
        return values.sorted()
    }

    private var periodFilteredEntries: [BudgetEntry] {
        let allEntries = budgetStore?.entries ?? []
        guard let startDate = selectedRangeFilter.startDate else { return allEntries }
        return allEntries.filter { $0.transactionDate >= startDate }
    }

    private var filteredEntries: [BudgetEntry] {
        var values = periodFilteredEntries.sorted(by: { $0.transactionDate < $1.transactionDate })
        if selectedKindFilter != .all {
            values = values.filter { $0.kind.rawValue == selectedKindFilter.rawValue }
        }
        if selectedCategoryFilter != String(localized: "budget.filter.option.all") {
            values = values.filter { $0.category == selectedCategoryFilter }
        }
        let query = normalizedSearchQuery
        if !query.isEmpty {
            values = values.filter { entry in
                entry.title.localizedCaseInsensitiveContains(query)
                    || entry.category.localizedCaseInsensitiveContains(query)
                    || (entry.subcategory?.localizedCaseInsensitiveContains(query) ?? false)
                    || (entry.merchantName?.localizedCaseInsensitiveContains(query) ?? false)
                    || (entry.notes?.localizedCaseInsensitiveContains(query) ?? false)
            }
        }
        return values
    }

    private var recentTransactions: [BudgetEntry] {
        Array(filteredEntries.sorted(by: { $0.transactionDate > $1.transactionDate }).prefix(20))
    }

    private var limitsByCategory: [String: Double] {
        Dictionary(uniqueKeysWithValues: appPreferences.budgetCategoryLimits.map { ($0.category, $0.amount) })
    }

    private var summarySnapshot: BudgetSummarySnapshot {
        budgetStore.map { BudgetAnalyticsService().summary(entries: filteredEntries, openingBalance: $0.openingBalance) }
            ?? BudgetSummarySnapshot(income: 0, expense: 0, net: 0, currentBalance: 0)
    }

    private var currentInterval: DateInterval {
        if let interval = selectedRangeFilter.dateInterval {
            return interval
        }

        let entries = budgetStore?.entries ?? []
        if
            let minDate = entries.map(\.transactionDate).min(),
            let maxDate = entries.map(\.transactionDate).max()
        {
            return DateInterval(start: minDate, end: maxDate)
        }

        return DateInterval(start: Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now, end: .now)
    }

    private var cashFlowPoints: [BudgetCashFlowPoint] {
        budgetStore?.cashFlow(interval: currentInterval) ?? []
    }

    private var runningBalancePoints: [BudgetRunningBalancePoint] {
        budgetStore?.runningBalance(interval: selectedRangeFilter.dateInterval) ?? []
    }

    private var categoryBreakdownPoints: [BudgetCategoryBreakdownPoint] {
        budgetStore?.categoryBreakdown(for: filteredEntries, limits: limitsByCategory) ?? []
    }

    private var upcomingRecurringPoints: [BudgetUpcomingRecurringPoint] {
        budgetStore?.upcomingRecurring(limit: 6) ?? []
    }

    private var categorySummaries: [PhoneBudgetCategorySummary] {
        let categories = budgetStore?.categoryBreakdown(for: filteredEntries, limits: limitsByCategory) ?? []
        return categories.map { point in
            PhoneBudgetCategorySummary(category: point.category, spent: point.amount, limit: point.limit)
        }
    }

    private var filteredGoals: [BudgetGoal] {
        let query = normalizedSearchQuery
        let goals = budgetStore?.goals ?? []
        guard !query.isEmpty else { return goals }
        return goals.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private var budgetCurrencyCode: String {
        budgetStore?.currencyCode ?? "PLN"
    }

    private var hasActiveFilters: Bool {
        selectedKindFilter != .all || selectedRangeFilter != .month || selectedCategoryFilter != String(localized: "budget.filter.option.all")
    }

    private var normalizedSearchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resetFilters() {
        selectedKindFilter = .all
        selectedRangeFilter = .month
        selectedCategoryFilter = String(localized: "budget.filter.option.all")
    }

    @ViewBuilder
    private func filterMenuLabel(title: String, isSelected: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
            }
        }
    }

    @MainActor
    private func setupStoreIfNeeded(performRemoteRefresh: Bool = true) async {
        guard budgetStore == nil else { return }
        let repo = BudgetRepository(client: SupabaseConfig.client, context: modelContext)
        let store = BudgetStore(modelContext: modelContext, repository: repo)
        budgetStore = store
        store.setSpace(spaceRepo.selectedSpace?.id)

        if performRemoteRefresh && !isPreview {
            await store.refreshRemote()
        }
    }

    @MainActor
    private func refreshBudget() async {
        await budgetStore?.syncPending()
        await budgetStore?.refreshRemote()
    }
}

#Preview("budget.view.title") {
    let schema = Schema([
        UserProfile.self,
        Space.self,
        SpaceMembership.self,
        SpaceInvitation.self,
        Mission.self,
        Incident.self,
        LinkedThing.self,
        Assignment.self,
        BudgetEntry.self,
        BudgetRecurringRule.self,
        BudgetSpaceSettings.self,
        BudgetGoal.self
    ])
    let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext

    let user = UserProfile(id: UUID(), email: "preview@ufo.app", fullName: "Preview User", role: "admin")
    let space = Space(id: UUID(), name: "Family Crew", inviteCode: "UFO123")
    context.insert(user)
    context.insert(space)
    context.insert(SpaceMembership(user: user, space: space, role: "admin"))

    context.insert(BudgetEntry(spaceId: space.id, title: "Salary", kind: .income, amount: 4200, category: "Work", merchantName: "Employer"))
    context.insert(BudgetEntry(spaceId: space.id, title: "Groceries", kind: .expense, amount: 350, category: "Food", merchantName: "Lidl", isFixed: false))
    context.insert(BudgetRecurringRule(spaceId: space.id, title: "Netflix", kind: .expense, amount: 67, category: "Subscriptions", merchantName: "Netflix", cadence: .monthly))
    context.insert(BudgetSpaceSettings(id: space.id, spaceId: space.id, openingBalance: 2100, currencyCode: "PLN"))
    context.insert(BudgetGoal(spaceId: space.id, title: "Vacation", targetAmount: 5000, currentAmount: 1200))

    try? context.save()

    let authRepo = AuthRepository(client: SupabaseConfig.client, isLoggedIn: true, currentUser: user)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    spaceRepo.selectedSpace = space

    return PhoneBudgetScreen()
        .environment(authRepo)
        .environment(spaceRepo)
        .modelContainer(container)
}

#endif
