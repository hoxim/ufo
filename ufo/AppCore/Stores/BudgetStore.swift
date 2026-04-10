import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class BudgetStore {
    private let modelContext: ModelContext
    private let repository: BudgetRepository
    private let analytics = BudgetAnalyticsService()
    private var cloudSyncEnabled: Bool { AppPreferences.shared.isCloudSyncEnabled }

    var entries: [BudgetEntry] = []
    var recurringRules: [BudgetRecurringRule] = []
    var goals: [BudgetGoal] = []
    var spaceSettings: BudgetSpaceSettings?
    var currentSpaceId: UUID?
    var isSyncing: Bool = false
    var lastErrorMessage: String?

    init(modelContext: ModelContext, repository: BudgetRepository) {
        self.modelContext = modelContext
        self.repository = repository
    }

    func setSpace(_ spaceId: UUID?) {
        currentSpaceId = spaceId
        guard let spaceId else {
            entries = []
            recurringRules = []
            goals = []
            spaceSettings = nil
            return
        }
        loadLocal(spaceId: spaceId)
    }

    func loadLocal(spaceId: UUID) {
        do {
            entries = try repository.fetchEntriesLocal(spaceId: spaceId)
            recurringRules = try repository.fetchRecurringRulesLocal(spaceId: spaceId)
            goals = try repository.fetchGoalsLocal(spaceId: spaceId)
            spaceSettings = try repository.fetchSpaceSettingsLocal(spaceId: spaceId)
            lastErrorMessage = nil
        } catch {
            entries = []
            recurringRules = []
            goals = []
            spaceSettings = nil
            lastErrorMessage = localizedErrorMessage("budget.error.loadLocal", error: error)
        }
    }

    func refreshRemote() async {
        guard let spaceId = currentSpaceId else { return }
        guard cloudSyncEnabled else {
            loadLocal(spaceId: spaceId)
            ensureLocalSpaceSettings()
            return
        }
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await repository.pullRemoteToLocal(spaceId: spaceId)
            entries = try repository.fetchEntriesLocal(spaceId: spaceId)
            recurringRules = try repository.fetchRecurringRulesLocal(spaceId: spaceId)
            goals = try repository.fetchGoalsLocal(spaceId: spaceId)
            spaceSettings = try repository.fetchSpaceSettingsLocal(spaceId: spaceId)
            ensureLocalSpaceSettings()
            lastErrorMessage = nil
        } catch {
            loadLocal(spaceId: spaceId)
            ensureLocalSpaceSettings()
            lastErrorMessage = localizedErrorMessage("budget.error.refresh", error: error)
        }
    }

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

            reloadCurrentSpace()
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
            reloadCurrentSpace()
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
            reloadCurrentSpace()
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
            entries = try repository.fetchEntriesLocal(spaceId: spaceId)
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

    func syncPending() async {
        guard let spaceId = currentSpaceId else { return }
        guard cloudSyncEnabled else {
            loadLocal(spaceId: spaceId)
            ensureLocalSpaceSettings()
            lastErrorMessage = nil
            return
        }
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await repository.syncPendingLocal(spaceId: spaceId)
            try await repository.pullRemoteToLocal(spaceId: spaceId)
            reloadCurrentSpace()
            try modelContext.save()
            notifyHomeWidgetsDataDidChange()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = localizedErrorMessage("budget.error.sync", error: error)
        }
    }

    var currencyCode: String {
        spaceSettings?.currencyCode ?? "PLN"
    }

    var openingBalance: Double {
        spaceSettings?.openingBalance ?? 0
    }

    var summarySnapshot: BudgetSummarySnapshot {
        analytics.summary(entries: entries, openingBalance: openingBalance)
    }

    var totalIncome: Double {
        summarySnapshot.income
    }

    var totalExpense: Double {
        summarySnapshot.expense
    }

    var balance: Double {
        summarySnapshot.currentBalance
    }

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

    private func reloadCurrentSpace() {
        guard let spaceId = currentSpaceId else { return }
        loadLocal(spaceId: spaceId)
        ensureLocalSpaceSettings()
    }

    private func ensureLocalSpaceSettings() {
        guard let currentSpaceId, spaceSettings == nil else { return }
        do {
            spaceSettings = try repository.upsertSpaceSettingsLocal(
                spaceId: currentSpaceId,
                openingBalance: 0,
                currencyCode: "PLN",
                actor: nil
            )
        } catch {
            Log.error("BudgetStore.ensureLocalSpaceSettings failed for spaceId=\(currentSpaceId.uuidString): \(error.localizedDescription)")
        }
    }
}
