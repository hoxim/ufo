#if os(iOS)

import SwiftUI
import SwiftData
import Charts

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
    @State private var editingCategoryBudget: BudgetCategoryLimitPreference?
    @State private var didAutoPresentAddEntry = false
    @State private var selectedKindFilter: PhoneBudgetKindFilter = .all
    @State private var selectedRangeFilter: PhoneBudgetRangeFilter = .month
    @State private var selectedCategoryFilter = "All"
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
                        Section("Period") {
                            ForEach(PhoneBudgetRangeFilter.allCases, id: \.self) { filter in
                                Button {
                                    selectedRangeFilter = filter
                                } label: {
                                    filterMenuLabel(title: filter.title, isSelected: selectedRangeFilter == filter)
                                }
                            }
                        }

                        Section("Type") {
                            ForEach(PhoneBudgetKindFilter.allCases, id: \.self) { filter in
                                Button {
                                    selectedKindFilter = filter
                                } label: {
                                    filterMenuLabel(title: filter.title, isSelected: selectedKindFilter == filter)
                                }
                            }
                        }

                        Section("Category") {
                            Button {
                                selectedCategoryFilter = "All"
                            } label: {
                                filterMenuLabel(title: "All", isSelected: selectedCategoryFilter == "All")
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

                            Button("Reset Filters") {
                                resetFilters()
                            }
                        }
                } label: {
                    Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
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
            FeatureBottomSearchBar(text: $searchText, prompt: "Search budget")
        }
    }

    private var contentList: some View {
        List {
            if let error = budgetStore?.lastErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            PhoneBudgetOverviewSection(
                income: filteredIncome,
                expense: filteredExpense,
                balance: filteredBalance
            )

            if budgetStore != nil, !filteredEntries.isEmpty {
                PhoneBudgetCashFlowSection(entries: chartEntries)
            }

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

            if !subscriptionEntries.isEmpty {
                PhoneBudgetSubscriptionsSection(entries: subscriptionEntries)
            }

            PhoneBudgetGoalsSection(
                goals: filteredGoals,
                onAddGoal: { showAddGoal = true }
            )

            PhoneBudgetTransactionsSection(
                entries: filteredEntries,
                onDelete: { offsets in
                    guard let store = budgetStore else { return }
                    let values = offsets.map { filteredEntries[$0] }
                    Task {
                        for entry in values {
                            await store.deleteEntry(entry, actor: authRepo.currentUser?.id)
                        }
                    }
                }
            )
        }
    }

    /// Handles last entries for chart.
    private func lastEntriesForChart(from entries: [BudgetEntry]) -> [BudgetEntry] {
        Array(entries.sorted(by: { $0.entryDate < $1.entryDate }).suffix(14))
    }

    private var filteredEntries: [BudgetEntry] {
        var values = periodFilteredEntries.sorted(by: { $0.entryDate < $1.entryDate })
        if selectedKindFilter != .all {
            values = values.filter { $0.kind == selectedKindFilter.rawValue }
        }
        if selectedCategoryFilter != "All" {
            values = values.filter { $0.category == selectedCategoryFilter }
        }
        let query = normalizedSearchQuery
        if !query.isEmpty {
            values = values.filter { entry in
                entry.title.localizedCaseInsensitiveContains(query)
                    || entry.category.localizedCaseInsensitiveContains(query)
                    || (entry.notes?.localizedCaseInsensitiveContains(query) ?? false)
            }
        }
        return values
    }

    private var chartEntries: [BudgetEntry] {
        lastEntriesForChart(from: filteredEntries)
    }

    private var availableCategories: [String] {
        let values = Set(PhoneBudgetPresetCategory.allCases.map(\.title) + appPreferences.budgetCustomCategories + (budgetStore?.entries ?? []).map(\.category))
        return values.sorted()
    }

    private var periodFilteredEntries: [BudgetEntry] {
        let allEntries = budgetStore?.entries ?? []
        guard let startDate = selectedRangeFilter.startDate else { return allEntries }
        return allEntries.filter { $0.entryDate >= startDate }
    }

    private var subscriptionEntries: [BudgetEntry] {
        filteredEntries
            .filter { $0.kind == BudgetEntryKind.expense.rawValue && ($0.isRecurring || $0.category.localizedCaseInsensitiveContains("subscription")) }
            .sorted { $0.amount > $1.amount }
    }

    private var categorySummaries: [PhoneBudgetCategorySummary] {
        let expenseEntries = periodFilteredEntries.filter { $0.kind == BudgetEntryKind.expense.rawValue }
        let grouped = Dictionary(grouping: expenseEntries, by: \.category)
        let limits = Dictionary(uniqueKeysWithValues: appPreferences.budgetCategoryLimits.map { ($0.category, $0.amount) })

        let categories = Set(grouped.keys).union(limits.keys)

        return categories
            .map { category in
                let spent = grouped[category, default: []].reduce(0) { $0 + $1.amount }
                let limit = limits[category]
                return PhoneBudgetCategorySummary(category: category, spent: spent, limit: limit)
            }
            .sorted { lhs, rhs in
                if lhs.isOverLimit != rhs.isOverLimit {
                    return lhs.isOverLimit && !rhs.isOverLimit
                }
                return lhs.category.localizedCaseInsensitiveCompare(rhs.category) == .orderedAscending
            }
            .filter { summary in
                let query = normalizedSearchQuery
                return query.isEmpty || summary.category.localizedCaseInsensitiveContains(query)
            }
    }

    private var filteredIncome: Double {
        filteredEntries
            .filter { $0.kind == BudgetEntryKind.income.rawValue }
            .reduce(0) { $0 + $1.amount }
    }

    private var filteredExpense: Double {
        filteredEntries
            .filter { $0.kind == BudgetEntryKind.expense.rawValue }
            .reduce(0) { $0 + $1.amount }
    }

    private var filteredBalance: Double {
        filteredIncome - filteredExpense
    }

    private var hasActiveFilters: Bool {
        selectedKindFilter != .all || selectedRangeFilter != .month || selectedCategoryFilter != "All"
    }

    private var filteredGoals: [BudgetGoal] {
        let query = normalizedSearchQuery
        let goals = budgetStore?.goals ?? []
        guard !query.isEmpty else { return goals }
        return goals.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private var normalizedSearchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resetFilters() {
        selectedKindFilter = .all
        selectedRangeFilter = .month
        selectedCategoryFilter = "All"
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
    /// Sets up store if needed.
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
        BudgetGoal.self
    ])
    let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext

    let user = UserProfile(id: UUID(), email: "preview@ufo.app", fullName: "Preview User", role: "admin")
    let space = Space(id: UUID(), name: "Family Crew", inviteCode: "UFO123")
    context.insert(user)
    context.insert(space)
    context.insert(SpaceMembership(user: user, space: space, role: "admin"))

    context.insert(BudgetEntry(spaceId: space.id, title: "Salary", kind: "income", amount: 4200, category: "Work"))
    context.insert(BudgetEntry(spaceId: space.id, title: "Groceries", kind: "expense", amount: 350, category: "Food"))
    context.insert(BudgetGoal(spaceId: space.id, title: "Vacation", targetAmount: 5000, currentAmount: 1200))

    do {
        try context.save()
    } catch {
        Log.dbError("Budget preview context.save", error)
    }

    let authRepo = AuthRepository(client: SupabaseConfig.client, isLoggedIn: true, currentUser: user)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    spaceRepo.selectedSpace = space

    return PhoneBudgetScreen()
        .environment(authRepo)
        .environment(spaceRepo)
        .modelContainer(container)
}

#endif
