import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class BudgetStore {
    private let modelContext: ModelContext
    private let repository: BudgetRepository

    var entries: [BudgetEntry] = []
    var goals: [BudgetGoal] = []
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
            goals = []
            return
        }
        loadLocal(spaceId: spaceId)
    }

    func loadLocal(spaceId: UUID) {
        do {
            entries = try repository.fetchEntriesLocal(spaceId: spaceId)
            goals = try repository.fetchGoalsLocal(spaceId: spaceId)
            lastErrorMessage = nil
        } catch {
            entries = []
            goals = []
            lastErrorMessage = "Nie udało się wczytać budżetu lokalnie: \(error)"
        }
    }

    func refreshRemote() async {
        guard let spaceId = currentSpaceId else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await repository.pullRemoteToLocal(spaceId: spaceId)
            entries = try repository.fetchEntriesLocal(spaceId: spaceId)
            goals = try repository.fetchGoalsLocal(spaceId: spaceId)
            lastErrorMessage = nil
        } catch {
            loadLocal(spaceId: spaceId)
            lastErrorMessage = "Nie udało się odświeżyć budżetu: \(error)"
        }
    }

    func addEntry(title: String, kind: BudgetEntryKind, amount: Double, category: String, notes: String?, date: Date, recurring: Bool, recurringInterval: String?, actor: UUID?) async {
        guard let spaceId = currentSpaceId else { return }
        do {
            _ = try repository.createEntryLocal(
                spaceId: spaceId,
                title: title,
                kind: kind,
                amount: amount,
                category: category,
                notes: notes,
                date: date,
                recurring: recurring,
                recurringInterval: recurringInterval,
                actor: actor
            )
            entries = try repository.fetchEntriesLocal(spaceId: spaceId)
            await syncPending()
        } catch {
            lastErrorMessage = "Nie udało się dodać wpisu budżetu: \(error)"
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
            goals = try repository.fetchGoalsLocal(spaceId: spaceId)
            await syncPending()
        } catch {
            lastErrorMessage = "Nie udało się dodać celu budżetowego: \(error)"
        }
    }

    func updateGoalProgress(_ goal: BudgetGoal, currentAmount: Double, actor: UUID?) async {
        guard let spaceId = currentSpaceId else { return }
        do {
            try repository.markGoalUpdatedLocal(goal, currentAmount: currentAmount, actor: actor)
            goals = try repository.fetchGoalsLocal(spaceId: spaceId)
            await syncPending()
        } catch {
            lastErrorMessage = "Nie udało się zaktualizować celu: \(error)"
        }
    }

    func deleteEntry(_ entry: BudgetEntry, actor: UUID?) async {
        guard let spaceId = currentSpaceId else { return }
        do {
            try repository.markEntryDeletedLocal(entry, actor: actor)
            entries = try repository.fetchEntriesLocal(spaceId: spaceId)
            await syncPending()
        } catch {
            lastErrorMessage = "Nie udało się usunąć wpisu budżetu: \(error)"
        }
    }

    func syncPending() async {
        guard let spaceId = currentSpaceId else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await repository.syncPendingLocal(spaceId: spaceId)
            try await repository.pullRemoteToLocal(spaceId: spaceId)
            entries = try repository.fetchEntriesLocal(spaceId: spaceId)
            goals = try repository.fetchGoalsLocal(spaceId: spaceId)
            try modelContext.save()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Nie udało się zsynchronizować budżetu: \(error)"
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
