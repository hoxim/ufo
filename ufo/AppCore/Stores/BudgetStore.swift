import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class BudgetStore {
    private let modelContext: ModelContext
    private let repository: BudgetRepository
    private var cloudSyncEnabled: Bool { AppPreferences.shared.isCloudSyncEnabled }

    var entries: [BudgetEntry] = []
    var goals: [BudgetGoal] = []
    var currentSpaceId: UUID?
    var isSyncing: Bool = false
    var lastErrorMessage: String?

    init(modelContext: ModelContext, repository: BudgetRepository) {
        self.modelContext = modelContext
        self.repository = repository
    }

    /// Sets space.
    func setSpace(_ spaceId: UUID?) {
        currentSpaceId = spaceId
        guard let spaceId else {
            entries = []
            goals = []
            return
        }
        loadLocal(spaceId: spaceId)
    }

    /// Loads local.
    func loadLocal(spaceId: UUID) {
        do {
            entries = try repository.fetchEntriesLocal(spaceId: spaceId)
            goals = try repository.fetchGoalsLocal(spaceId: spaceId)
            lastErrorMessage = nil
        } catch {
            entries = []
            goals = []
            lastErrorMessage = localizedErrorMessage("budget.error.loadLocal", error: error)
        }
    }

    /// Handles refresh remote.
    func refreshRemote() async {
        guard let spaceId = currentSpaceId else { return }
        guard cloudSyncEnabled else {
            loadLocal(spaceId: spaceId)
            return
        }
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await repository.pullRemoteToLocal(spaceId: spaceId)
            entries = try repository.fetchEntriesLocal(spaceId: spaceId)
            goals = try repository.fetchGoalsLocal(spaceId: spaceId)
            lastErrorMessage = nil
        } catch {
            loadLocal(spaceId: spaceId)
            lastErrorMessage = localizedErrorMessage("budget.error.refresh", error: error)
        }
    }

    /// Handles add entry.
    func addEntry(title: String, kind: BudgetEntryKind, amount: Double, category: String, iconName: String?, iconColorHex: String?, notes: String?, date: Date, recurring: Bool, recurringInterval: String?, actor: UUID?) async {
        guard let spaceId = currentSpaceId else { return }
        do {
            _ = try repository.createEntryLocal(
                spaceId: spaceId,
                title: title,
                kind: kind,
                amount: amount,
                category: category,
                iconName: iconName,
                iconColorHex: iconColorHex,
                notes: notes,
                date: date,
                recurring: recurring,
                recurringInterval: recurringInterval,
                actor: actor
            )
            entries = try repository.fetchEntriesLocal(spaceId: spaceId)
            notifyHomeWidgetsDataDidChange()
            await syncPending()
        } catch {
            lastErrorMessage = localizedErrorMessage("budget.error.addEntry", error: error)
        }
    }

    /// Handles add goal.
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
            goals = try repository.fetchGoalsLocal(spaceId: spaceId)
            notifyHomeWidgetsDataDidChange()
            await syncPending()
        } catch {
            lastErrorMessage = localizedErrorMessage("budget.error.addGoal", error: error)
        }
    }

    /// Updates goal progress.
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

    /// Deletes entry.
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

    /// Syncs pending.
    func syncPending() async {
        guard let spaceId = currentSpaceId else { return }
        guard cloudSyncEnabled else {
            loadLocal(spaceId: spaceId)
            lastErrorMessage = nil
            return
        }
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await repository.syncPendingLocal(spaceId: spaceId)
            try await repository.pullRemoteToLocal(spaceId: spaceId)
            entries = try repository.fetchEntriesLocal(spaceId: spaceId)
            goals = try repository.fetchGoalsLocal(spaceId: spaceId)
            try modelContext.save()
            notifyHomeWidgetsDataDidChange()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = localizedErrorMessage("budget.error.sync", error: error)
        }
    }

    var totalIncome: Double {
        entries.filter { $0.kind == BudgetEntryKind.income.rawValue }.reduce(0) { $0 + $1.amount }
    }

    var totalExpense: Double {
        entries.filter { $0.kind == BudgetEntryKind.expense.rawValue }.reduce(0) { $0 + $1.amount }
    }

    var balance: Double { totalIncome - totalExpense }
}
