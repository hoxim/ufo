import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class BudgetStore: SpaceScopedStore {
    let modelContext: ModelContext
    private let repository: BudgetRepository
    private let analytics = BudgetAnalyticsService()

    var entries: [BudgetEntry] = []
    var recurringRules: [BudgetRecurringRule] = []
    var goals: [BudgetGoal] = []
    var spaceSettings: BudgetSpaceSettings?
    var currentSpaceId: UUID?
    var isSyncing = false
    var lastErrorMessage: String?

    // Cached analytics snapshot — invalidated on every loadLocal()
    private var _summaryCache: BudgetSummarySnapshot?

    init(modelContext: ModelContext, repository: BudgetRepository) {
        self.modelContext = modelContext
        self.repository = repository
    }

    // MARK: - SpaceScopedStore

    func clearSpaceData() {
        entries = []
        recurringRules = []
        goals = []
        spaceSettings = nil
        _summaryCache = nil
    }

    func loadLocal(spaceId: UUID) {
        do {
            entries = try repository.fetchEntriesLocal(spaceId: spaceId)
            recurringRules = try repository.fetchRecurringRulesLocal(spaceId: spaceId)
            goals = try repository.fetchGoalsLocal(spaceId: spaceId)
            spaceSettings = try repository.fetchSpaceSettingsLocal(spaceId: spaceId)
            _summaryCache = nil
            ensureLocalSpaceSettings()
            lastErrorMessage = nil
        } catch {
            clearSpaceData()
            lastErrorMessage = error.localizedDescription
        }
    }

    func pullRemoteData(spaceId: UUID) async throws {
        try await repository.pullRemoteToLocal(spaceId: spaceId)
    }

    func syncPendingData(spaceId: UUID) async throws {
        try await repository.syncPendingLocal(spaceId: spaceId)
    }

    func afterSync() {
        notifyHomeWidgetsDataDidChange()
    }

    // MARK: - Analytics (cached)

    var currencyCode: String {
        spaceSettings?.currencyCode ?? "PLN"
    }

    var openingBalance: Double {
        spaceSettings?.openingBalance ?? 0
    }

    /// Computed once per data load — not recalculated on every access.
    var summarySnapshot: BudgetSummarySnapshot {
        if let cached = _summaryCache { return cached }
        let snapshot = analytics.summary(entries: entries, openingBalance: openingBalance)
        _summaryCache = snapshot
        return snapshot
    }

    var totalIncome: Double  { summarySnapshot.income }
    var totalExpense: Double { summarySnapshot.expense }
    var balance: Double      { summarySnapshot.currentBalance }

    func cashFlow(interval: DateInterval) -> [BudgetCashFlowPoint] {
        analytics.cashFlow(entries: entries, in: interval)
    }

    func runningBalance(interval: DateInterval? = nil) -> [BudgetRunningBalancePoint] {
        analytics.runningBalance(entries: entries, openingBalance: openingBalance, in: interval)
    }

    func categoryBreakdown(for entries: [BudgetEntry], limits: [String: Double]) -> [BudgetCategoryBreakdownPoint] {
        analytics.categoryBreakdown(entries: entries, limits: limits)
    }

    func upcomingRecurring(limit: Int = 5) -> [BudgetUpcomingRecurringPoint] {
        analytics.upcomingRecurring(rules: recurringRules, limit: limit)
    }

    // MARK: - CRUD

    func addEntry(
        title: String,
        kind: BudgetEntryKind,
        amount: Double,
        category: String,
        subcategory: String? = nil,
        merchantName: String? = nil,
        merchantURLString: String? = nil,
        iconName: String?,
        iconColorHex: String?,
        notes: String?,
        date: Date,
        isFixed: Bool = false,
        recurring: Bool,
        recurringInterval: String?,
        actor: UUID?
    ) async {
        guard let spaceId = currentSpaceId else { return }
        do {
            _ = try repository.createEntryLocal(
                spaceId: spaceId,
                title: title,
                kind: kind,
                amount: amount,
                category: category,
                subcategory: subcategory,
                merchantName: merchantName,
                merchantURLString: merchantURLString,
                iconName: iconName,
                iconColorHex: iconColorHex,
                notes: notes,
                date: date,
                isFixed: isFixed,
                recurring: recurring,
                recurringInterval: recurringInterval,
                actor: actor
            )

            if recurring, let rawValue = recurringInterval, let cadence = BudgetRecurringCadence(rawValue: rawValue) {
                _ = try repository.createRecurringRuleLocal(
                    spaceId: spaceId,
                    title: title,
                    kind: kind,
                    amount: amount,
                    category: category,
                    subcategory: subcategory,
                    merchantName: merchantName,
                    merchantURLString: merchantURLString,
                    notes: notes,
                    cadence: cadence,
                    anchorDate: date,
                    isFixed: isFixed,
                    iconName: iconName,
                    iconColorHex: iconColorHex,
                    actor: actor
                )
            }

            loadLocal(spaceId: spaceId)
            notifyHomeWidgetsDataDidChange()
            await syncPending()
        } catch {
            lastErrorMessage = localizedErrorMessage("budget.error.addEntry", error: error)
        }
    }

    func addRecurringRule(
        title: String,
        kind: BudgetEntryKind,
        amount: Double,
        category: String,
        subcategory: String? = nil,
        merchantName: String? = nil,
        merchantURLString: String? = nil,
        notes: String? = nil,
        cadence: BudgetRecurringCadence,
        anchorDate: Date,
        isFixed: Bool,
        iconName: String?,
        iconColorHex: String?,
        actor: UUID?
    ) async {
        guard let spaceId = currentSpaceId else { return }
        do {
            _ = try repository.createRecurringRuleLocal(
                spaceId: spaceId,
                title: title,
                kind: kind,
                amount: amount,
                category: category,
                subcategory: subcategory,
                merchantName: merchantName,
                merchantURLString: merchantURLString,
                notes: notes,
                cadence: cadence,
                anchorDate: anchorDate,
                isFixed: isFixed,
                iconName: iconName,
                iconColorHex: iconColorHex,
                actor: actor
            )
            loadLocal(spaceId: spaceId)
            await syncPending()
        } catch {
            lastErrorMessage = localizedErrorMessage("budget.error.addEntry", error: error)
        }
    }

    func updateSpaceSettings(openingBalance: Double, currencyCode: String, actor: UUID?) async {
        guard let spaceId = currentSpaceId else { return }
        do {
            spaceSettings = try repository.upsertSpaceSettingsLocal(
                spaceId: spaceId,
                openingBalance: openingBalance,
                currencyCode: currencyCode,
                actor: actor
            )
            _summaryCache = nil
            notifyHomeWidgetsDataDidChange()
            await syncPending()
        } catch {
            lastErrorMessage = localizedErrorMessage("budget.error.sync", error: error)
        }
    }

    func addGoal(title: String, target: Double, current: Double, dueDate: Date?, actor: UUID?) async {
        guard let spaceId = currentSpaceId else { return }
        do {
            _ = try repository.createGoalLocal(
                spaceId: spaceId,
                title: title,
                targetAmount: target,
                currentAmount: current,
                dueDate: dueDate,
                actor: actor
            )
            loadLocal(spaceId: spaceId)
            notifyHomeWidgetsDataDidChange()
            await syncPending()
        } catch {
            lastErrorMessage = localizedErrorMessage("budget.error.addGoal", error: error)
        }
    }

    func updateGoalProgress(_ goal: BudgetGoal, currentAmount: Double, actor: UUID?) async {
        guard let spaceId = currentSpaceId else { return }
        do {
            try repository.markGoalUpdatedLocal(goal, currentAmount: currentAmount, actor: actor)
            goals = try repository.fetchGoalsLocal(spaceId: spaceId)
            notifyHomeWidgetsDataDidChange()
            await syncPending()
        } catch {
            lastErrorMessage = localizedErrorMessage("budget.error.updateGoal", error: error)
        }
    }

    func deleteEntry(_ entry: BudgetEntry, actor: UUID?) async {
        guard let spaceId = currentSpaceId else { return }
        do {
            try repository.markEntryDeletedLocal(entry, actor: actor)
            loadLocal(spaceId: spaceId)
            notifyHomeWidgetsDataDidChange()
            await syncPending()
        } catch {
            lastErrorMessage = localizedErrorMessage("budget.error.deleteEntry", error: error)
        }
    }

    func deleteRecurringRule(_ rule: BudgetRecurringRule, actor: UUID?) async {
        guard let spaceId = currentSpaceId else { return }
        do {
            try repository.markRecurringRuleDeletedLocal(rule, actor: actor)
            recurringRules = try repository.fetchRecurringRulesLocal(spaceId: spaceId)
            await syncPending()
        } catch {
            lastErrorMessage = localizedErrorMessage("budget.error.deleteEntry", error: error)
        }
    }

    // MARK: - Private

    private func ensureLocalSpaceSettings() {
        guard let currentSpaceId, spaceSettings == nil else { return }
        do {
            spaceSettings = try repository.upsertSpaceSettingsLocal(
                spaceId: currentSpaceId,
                openingBalance: 0,
                currencyCode: AppPreferences.shared.defaultCurrencyCode,
                actor: nil
            )
        } catch {
            Log.error("BudgetStore.ensureLocalSpaceSettings failed for spaceId=\(currentSpaceId.uuidString): \(error.localizedDescription)")
        }
    }
}
