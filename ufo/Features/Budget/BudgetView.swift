import SwiftUI
import SwiftData
import Charts

struct BudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo

    @State private var budgetStore: BudgetStore?
    @State private var showAddEntry = false
    @State private var showAddGoal = false
    @State private var didAutoPresentAddEntry = false
    @State private var selectedKindFilter: BudgetKindFilter = .all
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

                Section("budget.view.section.summary") {
                    LabeledContent("budget.view.summary.income", value: filteredIncome.formatted(.currency(code: "PLN")))
                    LabeledContent("budget.view.summary.expense", value: filteredExpense.formatted(.currency(code: "PLN")))
                    LabeledContent("budget.view.summary.balance", value: filteredBalance.formatted(.currency(code: "PLN")))
                }

                if budgetStore != nil {
                    Section("budget.view.section.flowChart") {
                        Chart {
                            ForEach(filteredEntries) { item in
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

                Section("Filters") {
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
                }

                Section("budget.view.section.goals") {
                    ForEach(budgetStore?.goals ?? []) { goal in
                        VStack(alignment: .leading) {
                            Text(goal.title).font(.headline)
                            ProgressView(value: goal.progress)
                            Text("\(goal.currentAmount.formatted(.currency(code: "PLN"))) / \(goal.targetAmount.formatted(.currency(code: "PLN")))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("budget.view.section.entries") {
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
                        showAddGoal = true
                    } label: {
                        Label("budget.view.action.goal", systemImage: "target")
                    }

                    Button {
                        showAddEntry = true
                    } label: {
                        Label("budget.view.action.entry", systemImage: "plus")
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
                    AddBudgetEntryView(store: budgetStore, actor: authRepo.currentUser?.id)
                        .presentationDetents([.medium])
                }
            }
            .sheet(isPresented: $showAddGoal) {
                if let budgetStore {
                    AddBudgetGoalView(store: budgetStore, actor: authRepo.currentUser?.id)
                        .presentationDetents([.medium])
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
        }
    }

    /// Handles last entries for chart.
    private func lastEntriesForChart(from entries: [BudgetEntry]) -> [BudgetEntry] {
        Array(entries.sorted(by: { $0.entryDate < $1.entryDate }).suffix(14))
    }

    private var filteredEntries: [BudgetEntry] {
        var values = (budgetStore?.entries ?? []).sorted(by: { $0.entryDate < $1.entryDate })
        if selectedKindFilter != .all {
            values = values.filter { $0.kind == selectedKindFilter.rawValue }
        }
        if selectedCategoryFilter != "All" {
            values = values.filter { $0.category == selectedCategoryFilter }
        }
        return lastEntriesForChart(from: values)
    }

    private var availableCategories: [String] {
        let values = Set((budgetStore?.entries ?? []).map(\.category))
        return values.sorted()
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

    @State private var title = ""
    @State private var kind: BudgetEntryKind = .expense
    @State private var amountText = ""
    @State private var category = "Groceries"
    @State private var iconName = "dollarsign.circle"
    @State private var iconColorHex = "#22C55E"
    @State private var notes = ""
    @State private var date = Date()
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
                TextField("budget.entry.field.amount", text: $amountText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                Picker("budget.entry.field.category", selection: $category) {
                    ForEach(categoryOptions(for: kind), id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                DisclosureGroup("Style", isExpanded: $showStylePicker) {
                    OperationStylePicker(iconName: $iconName, colorHex: $iconColorHex)
                }
                TextField("budget.entry.field.notes", text: $notes)
                DatePicker("budget.entry.field.date", selection: $date, displayedComponents: [.date])

            }
            .navigationTitle("budget.view.action.entry")
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
        await store.addEntry(
            title: title,
            kind: kind,
            amount: amount,
            category: category,
            iconName: iconName,
            iconColorHex: iconColorHex,
            notes: notes.isEmpty ? nil : notes,
            date: date,
            recurring: false,
            recurringInterval: nil,
            actor: actor
        )
        dismiss()
    }

    private func categoryOptions(for kind: BudgetEntryKind) -> [String] {
        switch kind {
        case .income:
            return ["Salary", "Freelance", "Refund", "Gift", "Other"]
        case .expense:
            return ["Groceries", "Subscriptions", "Transport", "Home", "Health", "Education", "Entertainment", "Other"]
        }
    }
}

private struct AddBudgetGoalView: View {
    @Environment(\.dismiss) private var dismiss

    let store: BudgetStore
    let actor: UUID?

    @State private var title = ""
    @State private var targetText = ""
    @State private var currentText = "0"
    @State private var dueDate = Date()
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("budget.goal.field.title", text: $title)
                TextField("budget.goal.field.targetAmount", text: $targetText)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
                TextField("budget.goal.field.currentAmount", text: $currentText)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
                DatePicker("budget.goal.field.dueDate", selection: $dueDate, displayedComponents: [.date])

            }
            .navigationTitle("budget.view.action.goal")
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
