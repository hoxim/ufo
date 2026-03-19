import SwiftUI
import SwiftData
import Charts

struct BudgetView: View {
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
    @State private var selectedKindFilter: BudgetKindFilter = .all
    @State private var selectedRangeFilter: BudgetRangeFilter = .month
    @State private var selectedCategoryFilter = "All"

    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    let autoPresentAddEntry: Bool

    init(autoPresentAddEntry: Bool = false) {
        self.autoPresentAddEntry = autoPresentAddEntry
    }

    var body: some View {
        NavigationStack {
            List {
                if let error = budgetStore?.lastErrorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Section {
                    Picker("Period", selection: $selectedRangeFilter) {
                        ForEach(BudgetRangeFilter.allCases, id: \.self) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Type", selection: $selectedKindFilter) {
                        ForEach(BudgetKindFilter.allCases, id: \.self) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Category", selection: $selectedCategoryFilter) {
                        Text("All").tag("All")
                        ForEach(availableCategories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                } header: {
                    Text("Filters")
                } footer: {
                    Text("Keep filters at the top to quickly narrow down transactions, subscriptions and category budgets.")
                }

                Section("Overview") {
                    LabeledContent("budget.view.summary.income", value: filteredIncome.formatted(.currency(code: "PLN")))
                    LabeledContent("budget.view.summary.expense", value: filteredExpense.formatted(.currency(code: "PLN")))
                    LabeledContent("budget.view.summary.balance", value: filteredBalance.formatted(.currency(code: "PLN")))
                }

                if budgetStore != nil, !filteredEntries.isEmpty {
                    Section("Cash Flow") {
                        Chart {
                            ForEach(chartEntries) { item in
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

                Section {
                    ForEach(categorySummaries) { summary in
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
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingCategoryBudget = BudgetCategoryLimitPreference(category: summary.category, amount: summary.limit ?? 0)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            appPreferences.removeBudgetCategoryLimit(category: categorySummaries[index].category)
                        }
                    }
                } header: {
                    HStack {
                        Text("Category Budgets")
                        Spacer()
                        Button {
                            showAddCategoryBudget = true
                        } label: {
                            Label("Add Limit", systemImage: "plus")
                        }
                        .buttonStyle(.borderless)
                    }
                } footer: {
                    Text("Set monthly limits for categories like Home, Food or Subscriptions, and compare them with the current spend.")
                }

                Section {
                    ForEach(appPreferences.budgetCustomCategories, id: \.self) { category in
                        Text(category)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            appPreferences.removeBudgetCustomCategory(appPreferences.budgetCustomCategories[index])
                        }
                    }
                } header: {
                    HStack {
                        Text("Custom Categories")
                        Spacer()
                        Button {
                            showAddCustomCategory = true
                        } label: {
                            Label("Add Category", systemImage: "plus")
                        }
                        .buttonStyle(.borderless)
                    }
                } footer: {
                    Text("Custom categories are available in the transaction form and can also have their own monthly limits.")
                }

                if !subscriptionEntries.isEmpty {
                Section("Subscriptions") {
                        ForEach(subscriptionEntries) { entry in
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
                }

                Section {
                    ForEach(budgetStore?.goals ?? []) { goal in
                        VStack(alignment: .leading) {
                            Text(goal.title).font(.headline)
                            ProgressView(value: goal.progress)
                            Text("\(goal.currentAmount.formatted(.currency(code: "PLN"))) / \(goal.targetAmount.formatted(.currency(code: "PLN")))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    HStack {
                        Text("Goals")
                        Spacer()
                        Button {
                            showAddGoal = true
                        } label: {
                            Label("Add Goal", systemImage: "plus")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                Section("Transactions") {
                    ForEach(filteredEntries) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                HStack {
                                    if let icon = entry.iconName {
                                        Image(systemName: icon)
                                            .foregroundStyle(Color(hex: entry.iconColorHex ?? "#22C55E"))
                                    }
                                    Text(entry.title).font(.headline)
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
                    .onDelete { offsets in
                        guard let store = budgetStore else { return }
                        let values = offsets.map { filteredEntries[$0] }
                        Task {
                            for entry in values {
                                await store.deleteEntry(entry, actor: authRepo.currentUser?.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("budget.view.title")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showAddEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await budgetStore?.syncPending() }
                    } label: {
                        Label("common.sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }
            .sheet(isPresented: $showAddEntry) {
                if let budgetStore {
                    AddBudgetEntryView(
                        store: budgetStore,
                        actor: authRepo.currentUser?.id,
                        customCategories: appPreferences.budgetCustomCategories
                    )
                        .presentationDetents([.medium, .large])
                }
            }
            .sheet(isPresented: $showAddGoal) {
                if let budgetStore {
                    AddBudgetGoalView(store: budgetStore, actor: authRepo.currentUser?.id)
                        .presentationDetents([.medium, .large])
                }
            }
            .sheet(isPresented: $showAddCategoryBudget) {
                AddCategoryBudgetView(
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
            .sheet(item: $editingCategoryBudget) { categoryBudget in
                AddCategoryBudgetView(
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
            .sheet(isPresented: $showAddCustomCategory) {
                AddCustomBudgetCategoryView { value in
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
        return values
    }

    private var chartEntries: [BudgetEntry] {
        lastEntriesForChart(from: filteredEntries)
    }

    private var availableCategories: [String] {
        let values = Set(BudgetPresetCategory.allCases.map(\.title) + appPreferences.budgetCustomCategories + (budgetStore?.entries ?? []).map(\.category))
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

    private var categorySummaries: [BudgetCategorySummary] {
        let expenseEntries = periodFilteredEntries.filter { $0.kind == BudgetEntryKind.expense.rawValue }
        let grouped = Dictionary(grouping: expenseEntries, by: \.category)
        let limits = Dictionary(uniqueKeysWithValues: appPreferences.budgetCategoryLimits.map { ($0.category, $0.amount) })

        let categories = Set(grouped.keys).union(limits.keys)

        return categories
            .map { category in
                let spent = grouped[category, default: []].reduce(0) { $0 + $1.amount }
                let limit = limits[category]
                return BudgetCategorySummary(category: category, spent: spent, limit: limit)
            }
            .sorted { lhs, rhs in
                if lhs.isOverLimit != rhs.isOverLimit {
                    return lhs.isOverLimit && !rhs.isOverLimit
                }
                return lhs.category.localizedCaseInsensitiveCompare(rhs.category) == .orderedAscending
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
}

private struct AddBudgetEntryView: View {
    @Environment(\.dismiss) private var dismiss

    let store: BudgetStore
    let actor: UUID?
    let customCategories: [String]

    @State private var title = ""
    @State private var kind: BudgetEntryKind = .expense
    @State private var amountText = ""
    @State private var category = BudgetPresetCategory.food.title
    @State private var customCategoryName = ""
    @State private var iconName = "dollarsign.circle"
    @State private var iconColorHex = "#22C55E"
    @State private var notes = ""
    @State private var date = Date()
    @State private var isRecurring = false
    @State private var recurringInterval: BudgetRecurringInterval = .monthly
    @State private var isSaving = false
    @State private var showStylePicker = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("budget.entry.field.title", text: $title)
                Picker("budget.entry.field.type", selection: $kind) {
                    ForEach(BudgetEntryKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .onChange(of: kind) { _, newValue in
                    if !categoryOptions(for: newValue).contains(category) {
                        category = categoryOptions(for: newValue).first ?? "Other"
                    }
                }
                TextField("budget.entry.field.amount", text: $amountText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                Picker("budget.entry.field.category", selection: $category) {
                    ForEach(categoryOptions(for: kind), id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                TextField("Custom category", text: $customCategoryName)
                Toggle("Recurring transaction", isOn: $isRecurring)
                if isRecurring {
                    Picker("Interval", selection: $recurringInterval) {
                        ForEach(BudgetRecurringInterval.allCases, id: \.self) { interval in
                            Text(interval.title).tag(interval)
                        }
                    }
                }
                DisclosureGroup("Style", isExpanded: $showStylePicker) {
                    OperationStylePicker(iconName: $iconName, colorHex: $iconColorHex)
                }
                TextField("budget.entry.field.notes", text: $notes)
                DatePicker("budget.entry.field.date", selection: $date, displayedComponents: [.date])

            }
            .navigationTitle("Add Transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let resolvedCategory = customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? category
            : customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)

        await store.addEntry(
            title: title,
            kind: kind,
            amount: amount,
            category: resolvedCategory,
            iconName: iconName,
            iconColorHex: iconColorHex,
            notes: notes.isEmpty ? nil : notes,
            date: date,
            recurring: isRecurring,
            recurringInterval: isRecurring ? recurringInterval.rawValue : nil,
            actor: actor
        )
        dismiss()
    }

    private func categoryOptions(for kind: BudgetEntryKind) -> [String] {
        switch kind {
        case .income:
            return (BudgetPresetIncomeCategory.allCases.map(\.title) + customCategories).uniquedPreservingOrder()
        case .expense:
            return (BudgetPresetCategory.allCases.map(\.title) + customCategories).uniquedPreservingOrder()
        }
    }
}

private struct AddBudgetGoalView: View {
    @Environment(\.dismiss) private var dismiss

    let store: BudgetStore
    let actor: UUID?

    @State private var title = ""
    @State private var targetText = ""
    @State private var currentText = ""
    @State private var dueDate = Date()
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Goal", text: $title)
                TextField("Target amount", text: $targetText)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
                TextField("Saved so far", text: $currentText)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
                DatePicker("Due date", selection: $dueDate, displayedComponents: [.date])

            }
            .navigationTitle("Add Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let target = Double(targetText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let current = Double(currentText.replacingOccurrences(of: ",", with: ".")) ?? 0
        await store.addGoal(title: title, target: target, current: current, dueDate: dueDate, actor: actor)
        dismiss()
    }
}

private struct AddCategoryBudgetView: View {
    @Environment(\.dismiss) private var dismiss

    let initialCategory: String?
    let initialAmount: Double?
    let customCategories: [String]
    let existingCategories: [String]
    let onSave: (String, Double) -> Void
    let onAddCategory: (String) -> Void

    @State private var selectedCategory: String
    @State private var customCategory: String
    @State private var amountText: String

    init(
        initialCategory: String?,
        initialAmount: Double?,
        customCategories: [String],
        existingCategories: [String],
        onSave: @escaping (String, Double) -> Void,
        onAddCategory: @escaping (String) -> Void
    ) {
        self.initialCategory = initialCategory
        self.initialAmount = initialAmount
        self.customCategories = customCategories
        self.existingCategories = existingCategories
        self.onSave = onSave
        self.onAddCategory = onAddCategory
        _selectedCategory = State(initialValue: initialCategory ?? existingCategories.first ?? BudgetPresetCategory.home.title)
        _customCategory = State(initialValue: "")
        if let initialAmount {
            _amountText = State(initialValue: String(format: "%.2f", initialAmount).replacingOccurrences(of: ".", with: ","))
        } else {
            _amountText = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(existingCategories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }

                TextField("New custom category", text: $customCategory)

                TextField("Monthly limit", text: $amountText)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
            }
            .navigationTitle(initialCategory == nil ? "Category Limit" : "Edit Limit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                }
            }
        }
    }

    private func save() {
        let newCategory = customCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedCategory = newCategory.isEmpty ? selectedCategory : newCategory
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard !resolvedCategory.isEmpty, amount > 0 else { return }

        if !newCategory.isEmpty, !customCategories.contains(where: { $0.caseInsensitiveCompare(newCategory) == .orderedSame }) {
            onAddCategory(newCategory)
        }

        onSave(resolvedCategory, amount)
        dismiss()
    }
}

private struct AddCustomBudgetCategoryView: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (String) -> Void

    @State private var value = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Category name", text: $value)
            }
            .navigationTitle("New Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !clean.isEmpty else { return }
                        onSave(clean)
                        dismiss()
                    }
                    .disabled(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private enum BudgetKindFilter: String, CaseIterable {
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

private enum BudgetRangeFilter: CaseIterable {
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

private enum BudgetRecurringInterval: String, CaseIterable {
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

private enum BudgetPresetCategory: CaseIterable {
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

private enum BudgetPresetIncomeCategory: CaseIterable {
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

private struct BudgetCategorySummary: Identifiable {
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
        if let limit {
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

private extension Array where Element == String {
    func uniquedPreservingOrder() -> [String] {
        var seen = Set<String>()
        return self.filter { value in
            let key = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            return seen.insert(key).inserted
        }
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

    return BudgetView()
        .environment(authRepo)
        .environment(spaceRepo)
        .modelContainer(container)
}
