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

    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    var body: some View {
        NavigationStack {
            List {
                if let error = budgetStore?.lastErrorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Section("Summary") {
                    LabeledContent("Income", value: (budgetStore?.totalIncome ?? 0).formatted(.currency(code: "PLN")))
                    LabeledContent("Expense", value: (budgetStore?.totalExpense ?? 0).formatted(.currency(code: "PLN")))
                    LabeledContent("Balance", value: (budgetStore?.balance ?? 0).formatted(.currency(code: "PLN")))
                }

                if let budgetStore {
                    Section("Flow chart") {
                        Chart {
                            ForEach(lastEntriesForChart(from: budgetStore.entries)) { item in
                                BarMark(
                                    x: .value("Day", item.entryDate, unit: .day),
                                    y: .value("Amount", item.kind == BudgetEntryKind.expense.rawValue ? -item.amount : item.amount)
                                )
                                .foregroundStyle(item.kind == BudgetEntryKind.expense.rawValue ? .red : .green)
                            }
                        }
                        .frame(height: 220)
                    }
                }

                Section("Goals") {
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

                Section("Entries") {
                    ForEach(budgetStore?.entries ?? []) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.title).font(.headline)
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
                        let values = offsets.map { store.entries[$0] }
                        Task {
                            for entry in values {
                                await store.deleteEntry(entry, actor: authRepo.currentUser?.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showAddGoal = true
                    } label: {
                        Label("Goal", systemImage: "target")
                    }

                    Button {
                        showAddEntry = true
                    } label: {
                        Label("Entry", systemImage: "plus")
                    }
                }

                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await budgetStore?.syncPending() }
                    } label: {
                        Label("Sync", systemImage: "arrow.triangle.2.circlepath")
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
            .task { await setupStoreIfNeeded() }
            .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
                budgetStore?.setSpace(newValue)
                Task { await budgetStore?.refreshRemote() }
            }
        }
    }

    private func lastEntriesForChart(from entries: [BudgetEntry]) -> [BudgetEntry] {
        Array(entries.sorted(by: { $0.entryDate < $1.entryDate }).suffix(14))
    }

    @MainActor
    private func setupStoreIfNeeded() async {
        guard budgetStore == nil else { return }
        let repo = BudgetRepository(client: SupabaseConfig.client, context: modelContext)
        let store = BudgetStore(modelContext: modelContext, repository: repo)
        budgetStore = store
        store.setSpace(spaceRepo.selectedSpace?.id)

        if !isPreview {
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
    @State private var category = "General"
    @State private var notes = ""
    @State private var date = Date()

    var body: some View {
        Form {
            TextField("Title", text: $title)
            Picker("Type", selection: $kind) {
                ForEach(BudgetEntryKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            TextField("Amount", text: $amountText)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
            TextField("Category", text: $category)
            TextField("Notes", text: $notes)
            DatePicker("Date", selection: $date, displayedComponents: [.date])

            Button("Save") {
                Task {
                    let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
                    await store.addEntry(
                        title: title,
                        kind: kind,
                        amount: amount,
                        category: category,
                        notes: notes.isEmpty ? nil : notes,
                        date: date,
                        recurring: false,
                        recurringInterval: nil,
                        actor: actor
                    )
                    dismiss()
                }
            }
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

    var body: some View {
        Form {
            TextField("Goal", text: $title)
            TextField("Target amount", text: $targetText)
            #if os(iOS)
                .keyboardType(.decimalPad)
            #endif
            TextField("Current amount", text: $currentText)
            #if os(iOS)
                .keyboardType(.decimalPad)
            #endif
            DatePicker("Due date", selection: $dueDate, displayedComponents: [.date])

            Button("Save") {
                Task {
                    let target = Double(targetText.replacingOccurrences(of: ",", with: ".")) ?? 0
                    let current = Double(currentText.replacingOccurrences(of: ",", with: ".")) ?? 0
                    await store.addGoal(title: title, target: target, current: current, dueDate: dueDate, actor: actor)
                    dismiss()
                }
            }
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

#Preview("Budget") {
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

    try? context.save()

    let authRepo = AuthRepository(client: SupabaseConfig.client, isLoggedIn: true, currentUser: user)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    spaceRepo.selectedSpace = space

    return BudgetView()
        .environment(authRepo)
        .environment(spaceRepo)
        .modelContainer(container)
}
