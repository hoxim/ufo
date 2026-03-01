import Foundation
import SwiftData
import Supabase

@MainActor
final class BudgetRepository {
    private let client: SupabaseClient
    private let context: ModelContext?

    init(client: SupabaseClient, context: ModelContext? = nil) {
        self.client = client
        self.context = context
    }

    struct BudgetEntryRecord: Codable {
        let id: UUID
        let spaceId: UUID
        let title: String
        let kind: String
        let amount: Double
        let category: String
        let notes: String?
        let entryDate: Date
        let isRecurring: Bool
        let recurringInterval: String?
        let createdBy: UUID?
        let createdAt: Date?
        let updatedAt: Date?
        let version: Int
        let updatedBy: UUID?
        let deletedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id, title, kind, amount, category, notes, version
            case spaceId = "space_id"
            case entryDate = "entry_date"
            case isRecurring = "is_recurring"
            case recurringInterval = "recurring_interval"
            case createdBy = "created_by"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case updatedBy = "updated_by"
            case deletedAt = "deleted_at"
        }
    }

    struct BudgetGoalRecord: Codable {
        let id: UUID
        let spaceId: UUID
        let title: String
        let targetAmount: Double
        let currentAmount: Double
        let dueDate: Date?
        let createdBy: UUID?
        let createdAt: Date?
        let updatedAt: Date?
        let version: Int
        let updatedBy: UUID?
        let deletedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id, title, version
            case spaceId = "space_id"
            case targetAmount = "target_amount"
            case currentAmount = "current_amount"
            case dueDate = "due_date"
            case createdBy = "created_by"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case updatedBy = "updated_by"
            case deletedAt = "deleted_at"
        }
    }

    private struct BudgetEntryPayload: Encodable {
        let id: UUID
        let space_id: UUID
        let title: String
        let kind: String
        let amount: Double
        let category: String
        let notes: String?
        let entry_date: Date
        let is_recurring: Bool
        let recurring_interval: String?
        let created_by: UUID?
        let updated_at: Date
        let version: Int
        let updated_by: UUID?
        let deleted_at: Date?
    }

    private struct BudgetGoalPayload: Encodable {
        let id: UUID
        let space_id: UUID
        let title: String
        let target_amount: Double
        let current_amount: Double
        let due_date: Date?
        let created_by: UUID?
        let updated_at: Date
        let version: Int
        let updated_by: UUID?
        let deleted_at: Date?
    }

    func fetchEntriesLocal(spaceId: UUID) throws -> [BudgetEntry] {
        guard let context else { return [] }
        return try context.fetch(
            FetchDescriptor<BudgetEntry>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.entryDate, order: .reverse)]
            )
        )
    }

    func fetchGoalsLocal(spaceId: UUID) throws -> [BudgetGoal] {
        guard let context else { return [] }
        return try context.fetch(
            FetchDescriptor<BudgetGoal>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )
    }

    func createEntryLocal(spaceId: UUID, title: String, kind: BudgetEntryKind, amount: Double, category: String, notes: String?, date: Date, recurring: Bool, recurringInterval: String?, actor: UUID?) throws -> BudgetEntry {
        guard let context else { throw RepositoryError.missingLocalContext }
        let entry = BudgetEntry(
            spaceId: spaceId,
            title: title,
            kind: kind.rawValue,
            amount: amount,
            category: category,
            notes: notes,
            entryDate: date,
            isRecurring: recurring,
            recurringInterval: recurringInterval,
            createdBy: actor
        )
        entry.pendingSync = true
        context.insert(entry)
        try context.save()
        return entry
    }

    func createGoalLocal(spaceId: UUID, title: String, targetAmount: Double, currentAmount: Double, dueDate: Date?, actor: UUID?) throws -> BudgetGoal {
        guard let context else { throw RepositoryError.missingLocalContext }
        let goal = BudgetGoal(
            spaceId: spaceId,
            title: title,
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            dueDate: dueDate,
            createdBy: actor
        )
        goal.pendingSync = true
        context.insert(goal)
        try context.save()
        return goal
    }

    func markEntryDeletedLocal(_ entry: BudgetEntry, actor: UUID?) throws {
        guard context != nil else { throw RepositoryError.missingLocalContext }
        entry.deletedAt = .now
        entry.updatedAt = .now
        entry.updatedBy = actor
        entry.version += 1
        entry.pendingSync = true
        try context?.save()
    }

    func markGoalUpdatedLocal(_ goal: BudgetGoal, currentAmount: Double, actor: UUID?) throws {
        guard context != nil else { throw RepositoryError.missingLocalContext }
        goal.currentAmount = currentAmount
        goal.updatedAt = .now
        goal.updatedBy = actor
        goal.version += 1
        goal.pendingSync = true
        try context?.save()
    }

    private func upsertEntryRemote(_ entry: BudgetEntry) async throws {
        let payload = BudgetEntryPayload(
            id: entry.id,
            space_id: entry.spaceId,
            title: entry.title,
            kind: entry.kind,
            amount: entry.amount,
            category: entry.category,
            notes: entry.notes,
            entry_date: entry.entryDate,
            is_recurring: entry.isRecurring,
            recurring_interval: entry.recurringInterval,
            created_by: entry.createdBy,
            updated_at: entry.updatedAt,
            version: entry.version,
            updated_by: entry.updatedBy,
            deleted_at: entry.deletedAt
        )

        try await client.from("budget_entries").upsert(payload).execute()
    }

    private func upsertGoalRemote(_ goal: BudgetGoal) async throws {
        let payload = BudgetGoalPayload(
            id: goal.id,
            space_id: goal.spaceId,
            title: goal.title,
            target_amount: goal.targetAmount,
            current_amount: goal.currentAmount,
            due_date: goal.dueDate,
            created_by: goal.createdBy,
            updated_at: goal.updatedAt,
            version: goal.version,
            updated_by: goal.updatedBy,
            deleted_at: goal.deletedAt
        )

        try await client.from("budget_goals").upsert(payload).execute()
    }

    func pullRemoteToLocal(spaceId: UUID) async throws {
        guard let context else { return }

        let remoteEntries: [BudgetEntryRecord] = try await client
            .from("budget_entries")
            .select("*")
            .eq("space_id", value: spaceId)
            .is("deleted_at", value: nil)
            .order("entry_date", ascending: false)
            .execute()
            .value

        for record in remoteEntries {
            let local = try context.fetch(FetchDescriptor<BudgetEntry>(predicate: #Predicate { $0.id == record.id })).first
            if let local {
                if local.version <= record.version {
                    local.title = record.title
                    local.kind = record.kind
                    local.amount = record.amount
                    local.category = record.category
                    local.notes = record.notes
                    local.entryDate = record.entryDate
                    local.isRecurring = record.isRecurring
                    local.recurringInterval = record.recurringInterval
                    local.createdBy = record.createdBy
                    local.createdAt = record.createdAt ?? local.createdAt
                    local.updatedAt = record.updatedAt ?? local.updatedAt
                    local.version = record.version
                    local.updatedBy = record.updatedBy
                    local.deletedAt = record.deletedAt
                    local.pendingSync = false
                }
            } else {
                let entry = BudgetEntry(
                    id: record.id,
                    spaceId: record.spaceId,
                    title: record.title,
                    kind: record.kind,
                    amount: record.amount,
                    category: record.category,
                    notes: record.notes,
                    entryDate: record.entryDate,
                    isRecurring: record.isRecurring,
                    recurringInterval: record.recurringInterval,
                    createdBy: record.createdBy
                )
                entry.createdAt = record.createdAt ?? .now
                entry.updatedAt = record.updatedAt ?? .now
                entry.version = record.version
                entry.updatedBy = record.updatedBy
                entry.deletedAt = record.deletedAt
                entry.pendingSync = false
                context.insert(entry)
            }
        }

        let remoteGoals: [BudgetGoalRecord] = try await client
            .from("budget_goals")
            .select("*")
            .eq("space_id", value: spaceId)
            .is("deleted_at", value: nil)
            .order("updated_at", ascending: false)
            .execute()
            .value

        for record in remoteGoals {
            let local = try context.fetch(FetchDescriptor<BudgetGoal>(predicate: #Predicate { $0.id == record.id })).first
            if let local {
                if local.version <= record.version {
                    local.title = record.title
                    local.targetAmount = record.targetAmount
                    local.currentAmount = record.currentAmount
                    local.dueDate = record.dueDate
                    local.createdBy = record.createdBy
                    local.createdAt = record.createdAt ?? local.createdAt
                    local.updatedAt = record.updatedAt ?? local.updatedAt
                    local.version = record.version
                    local.updatedBy = record.updatedBy
                    local.deletedAt = record.deletedAt
                    local.pendingSync = false
                }
            } else {
                let goal = BudgetGoal(
                    id: record.id,
                    spaceId: record.spaceId,
                    title: record.title,
                    targetAmount: record.targetAmount,
                    currentAmount: record.currentAmount,
                    dueDate: record.dueDate,
                    createdBy: record.createdBy
                )
                goal.createdAt = record.createdAt ?? .now
                goal.updatedAt = record.updatedAt ?? .now
                goal.version = record.version
                goal.updatedBy = record.updatedBy
                goal.deletedAt = record.deletedAt
                goal.pendingSync = false
                context.insert(goal)
            }
        }

        try context.save()
    }

    func syncPendingLocal(spaceId: UUID) async throws {
        guard let context else { return }

        let pendingEntries = try context.fetch(
            FetchDescriptor<BudgetEntry>(predicate: #Predicate { $0.spaceId == spaceId && $0.pendingSync == true })
        )
        for entry in pendingEntries {
            try await upsertEntryRemote(entry)
            entry.pendingSync = false
        }

        let pendingGoals = try context.fetch(
            FetchDescriptor<BudgetGoal>(predicate: #Predicate { $0.spaceId == spaceId && $0.pendingSync == true })
        )
        for goal in pendingGoals {
            try await upsertGoalRemote(goal)
            goal.pendingSync = false
        }

        try context.save()
    }
}
