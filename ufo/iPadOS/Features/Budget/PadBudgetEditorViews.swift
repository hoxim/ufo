#if os(iOS)

import SwiftUI


struct PadAddBudgetEntryView: View {
    @Environment(\.dismiss) private var dismiss

    let store: BudgetStore
    let actor: UUID?
    let customCategories: [String]

    @State private var title = ""
    @State private var kind: BudgetEntryKind = .expense
    @State private var amountText = ""
    @State private var category = PadBudgetPresetCategory.food.title
    @State private var customCategoryName = ""
    @State private var iconName = "dollarsign.circle"
    @State private var iconColorHex = "#22C55E"
    @State private var notes = ""
    @State private var date = Date()
    @State private var isRecurring = false
    @State private var recurringInterval: PadBudgetRecurringInterval = .monthly
    @State private var isSaving = false
    @State private var showStylePicker = false
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        AdaptiveFormContent {
            Form {
                TextField("budget.entry.field.title", text: $title)
                    .prominentFormTextInput()
                    .focused($isTitleFocused)
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
                    .prominentFormTextInput()
                    .decimalPadKeyboardIfSupported()
                Picker("budget.entry.field.category", selection: $category) {
                    ForEach(categoryOptions(for: kind), id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                TextField("Custom category", text: $customCategoryName)
                    .prominentFormTextInput()
                Toggle("Recurring transaction", isOn: $isRecurring)
                if isRecurring {
                    Picker("Interval", selection: $recurringInterval) {
                        ForEach(PadBudgetRecurringInterval.allCases, id: \.self) { interval in
                            Text(interval.title).tag(interval)
                        }
                    }
                }
                DisclosureGroup("Style", isExpanded: $showStylePicker) {
                    OperationStylePicker(iconName: $iconName, colorHex: $iconColorHex)
                }
                TextField("budget.entry.field.notes", text: $notes)
                    .prominentFormTextInput()
                DatePicker("budget.entry.field.date", selection: $date, displayedComponents: [.date])
            }
            .navigationTitle("Add Transaction")
            .modalInlineTitleDisplayMode()
            .toolbar {
                ModalCloseToolbarItem {
                    dismiss()
                }
                ModalConfirmToolbarItem(
                    isDisabled: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving,
                    isProcessing: isSaving,
                    action: { Task { await save() } }
                )
            }
            .onAppear {
                if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    isTitleFocused = true
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
            return (PadBudgetPresetIncomeCategory.allCases.map(\.title) + customCategories).uniquedPreservingOrder()
        case .expense:
            return (PadBudgetPresetCategory.allCases.map(\.title) + customCategories).uniquedPreservingOrder()
        }
    }
}

struct PadAddBudgetGoalView: View {
    @Environment(\.dismiss) private var dismiss

    let store: BudgetStore
    let actor: UUID?

    @State private var title = ""
    @State private var targetText = ""
    @State private var currentText = ""
    @State private var dueDate = Date()
    @State private var isSaving = false
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        AdaptiveFormContent {
            Form {
                TextField("Goal", text: $title)
                    .prominentFormTextInput()
                    .focused($isTitleFocused)
                TextField("Target amount", text: $targetText)
                    .prominentFormTextInput()
                    .decimalPadKeyboardIfSupported()
                TextField("Saved so far", text: $currentText)
                    .prominentFormTextInput()
                    .decimalPadKeyboardIfSupported()
                DatePicker("Due date", selection: $dueDate, displayedComponents: [.date])
            }
            .navigationTitle("Add Goal")
            .modalInlineTitleDisplayMode()
            .toolbar {
                ModalCloseToolbarItem {
                    dismiss()
                }
                ModalConfirmToolbarItem(
                    isDisabled: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving,
                    isProcessing: isSaving,
                    action: { Task { await save() } }
                )
            }
            .onAppear {
                if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    isTitleFocused = true
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

struct PadAddCategoryBudgetView: View {
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
        _selectedCategory = State(initialValue: initialCategory ?? existingCategories.first ?? PadBudgetPresetCategory.home.title)
        _customCategory = State(initialValue: "")
        if let initialAmount {
            _amountText = State(initialValue: String(format: "%.2f", initialAmount).replacingOccurrences(of: ".", with: ","))
        } else {
            _amountText = State(initialValue: "")
        }
    }

    var body: some View {
        AdaptiveFormContent {
            Form {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(existingCategories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }

                TextField("New custom category", text: $customCategory)
                    .prominentFormTextInput()

                TextField("Monthly limit", text: $amountText)
                    .prominentFormTextInput()
                    .decimalPadKeyboardIfSupported()
            }
            .navigationTitle(initialCategory == nil ? "Category Limit" : "Edit Limit")
            .modalInlineTitleDisplayMode()
            .toolbar {
                ModalCloseToolbarItem {
                    dismiss()
                }
                ModalConfirmToolbarItem(
                    isDisabled: false,
                    isProcessing: false,
                    action: save
                )
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

struct PadAddCustomBudgetCategoryView: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (String) -> Void

    @State private var value = ""

    var body: some View {
        AdaptiveFormContent {
            Form {
                TextField("Category name", text: $value)
                    .prominentFormTextInput()
            }
            .navigationTitle("New Category")
            .modalInlineTitleDisplayMode()
            .toolbar {
                ModalCloseToolbarItem {
                    dismiss()
                }
                ModalConfirmToolbarItem(
                    isDisabled: value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    isProcessing: false,
                    action: {
                        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !clean.isEmpty else { return }
                        onSave(clean)
                        dismiss()
                    }
                )
            }
        }
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


#endif
