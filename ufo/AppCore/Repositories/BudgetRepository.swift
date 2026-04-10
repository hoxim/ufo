import Foundation
import SwiftData
import Supabase

@MainActor
final class BudgetRepository {
    private let client: SupabaseClient
    private let context: ModelContext?
    private var supportsBudgetEntryExtendedSchema = true
    private var supportsRecurringRulesRemote = true
    private var supportsSpaceSettingsRemote = true

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
        let subcategory: String?
        let merchantName: String?
        let merchantURLString: String?
        let iconName: String?
        let iconColorHex: String?
        let notes: String?
        let entryDate: Date
        let isFixed: Bool?
        let isRecurring: Bool
        let recurringInterval: String?
        let createdBy: UUID?
        let createdAt: Date?
        let updatedAt: Date?
        let version: Int
        let updatedBy: UUID?
        let deletedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id, title, kind, amount, category, subcategory, notes, version
            case spaceId = "space_id"
            case merchantName = "merchant_name"
            case merchantURLString = "merchant_url"
            case iconName = "icon_name"
            case iconColorHex = "icon_color_hex"
            case entryDate = "entry_date"
            case isFixed = "is_fixed"
            case isRecurring = "is_recurring"
            case recurringInterval = "recurring_interval"
            case createdBy = "created_by"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case updatedBy = "updated_by"
            case deletedAt = "deleted_at"
        }
    }

    struct BudgetRecurringRuleRecord: Codable {
        let id: UUID
        let spaceId: UUID
        let title: String
        let kind: String
        let amount: Double
        let category: String
        let subcategory: String?
        let merchantName: String?
        let merchantURLString: String?
        let notes: String?
        let cadence: String
        let anchorDate: Date
        let isFixed: Bool
        let iconName: String?
        let iconColorHex: String?
        let isActive: Bool
        let createdBy: UUID?
        let createdAt: Date?
        let updatedAt: Date?
        let version: Int
        let updatedBy: UUID?
        let deletedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id, title, kind, amount, category, subcategory, notes, cadence, version
            case spaceId = "space_id"
            case merchantName = "merchant_name"
            case merchantURLString = "merchant_url"
            case anchorDate = "anchor_date"
            case isFixed = "is_fixed"
            case iconName = "icon_name"
            case iconColorHex = "icon_color_hex"
            case isActive = "is_active"
            case createdBy = "created_by"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case updatedBy = "updated_by"
            case deletedAt = "deleted_at"
        }
    }

    struct BudgetSpaceSettingsRecord: Codable {
        let id: UUID
        let spaceId: UUID
        let openingBalance: Double
        let currencyCode: String
        let createdAt: Date?
        let updatedAt: Date?
        let version: Int
        let updatedBy: UUID?

        enum CodingKeys: String, CodingKey {
            case id, version
            case spaceId = "space_id"
            case openingBalance = "opening_balance"
            case currencyCode = "currency_code"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case updatedBy = "updated_by"
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
        let subcategory: String?
        let merchant_name: String?
        let merchant_url: String?
        let icon_name: String?
        let icon_color_hex: String?
        let notes: String?
        let entry_date: Date
        let is_fixed: Bool
        let is_recurring: Bool
        let recurring_interval: String?
        let created_by: UUID?
        let updated_at: Date
        let version: Int
        let updated_by: UUID?
        let deleted_at: Date?
    }

    private struct BudgetEntryLegacyPayload: Encodable {
        let id: UUID
        let space_id: UUID
        let title: String
        let kind: String
        let amount: Double
        let category: String
        let icon_name: String?
        let icon_color_hex: String?
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

    private struct BudgetRecurringRulePayload: Encodable {
        let id: UUID
        let space_id: UUID
        let title: String
        let kind: String
        let amount: Double
        let category: String
        let subcategory: String?
        let merchant_name: String?
        let merchant_url: String?
        let notes: String?
        let cadence: String
        let anchor_date: Date
        let is_fixed: Bool
        let icon_name: String?
        let icon_color_hex: String?
        let is_active: Bool
        let created_by: UUID?
        let updated_at: Date
        let version: Int
        let updated_by: UUID?
        let deleted_at: Date?
    }

    private struct BudgetSpaceSettingsPayload: Encodable {
        let id: UUID
        let space_id: UUID
        let opening_balance: Double
        let currency_code: String
        let updated_at: Date
        let version: Int
        let updated_by: UUID?
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

    func fetchRecurringRulesLocal(spaceId: UUID) throws -> [BudgetRecurringRule] {
        guard let context else { return [] }
        return try context.fetch(
            FetchDescriptor<BudgetRecurringRule>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.anchorDate, order: .forward)]
            )
        )
    }

    func fetchSpaceSettingsLocal(spaceId: UUID) throws -> BudgetSpaceSettings? {
        guard let context else { return nil }
        return try context.fetch(
            FetchDescriptor<BudgetSpaceSettings>(
                predicate: #Predicate { $0.spaceId == spaceId },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        ).first
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

    func createEntryLocal(
        spaceId: UUID,
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
    ) throws -> BudgetEntry {
        guard let context else { throw RepositoryError.missingLocalContext }
        let entry = BudgetEntry(
            spaceId: spaceId,
            title: title,
            kind: kind.rawValue,
            amount: amount,
            category: category,
            subcategory: subcategory,
            merchantName: merchantName,
            merchantURLString: merchantURLString,
            iconName: iconName,
            iconColorHex: iconColorHex,
            notes: notes,
            entryDate: date,
            isFixed: isFixed,
            isRecurring: recurring,
            recurringInterval: recurringInterval,
            createdBy: actor
        )
        entry.pendingSync = true
        context.insert(entry)
        try context.save()
        return entry
    }

    func createRecurringRuleLocal(
        spaceId: UUID,
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
    ) throws -> BudgetRecurringRule {
        guard let context else { throw RepositoryError.missingLocalContext }
        let rule = BudgetRecurringRule(
            spaceId: spaceId,
            title: title,
            kind: kind.rawValue,
            amount: amount,
            category: category,
            subcategory: subcategory,
            merchantName: merchantName,
            merchantURLString: merchantURLString,
            notes: notes,
            cadence: cadence.rawValue,
            anchorDate: anchorDate,
            isFixed: isFixed,
            iconName: iconName,
            iconColorHex: iconColorHex,
            createdBy: actor
        )
        rule.pendingSync = true
        context.insert(rule)
        try context.save()
        return rule
    }

    func upsertSpaceSettingsLocal(spaceId: UUID, openingBalance: Double, currencyCode: String, actor: UUID?) throws -> BudgetSpaceSettings {
        guard let context else { throw RepositoryError.missingLocalContext }
        let settings = try fetchSpaceSettingsLocal(spaceId: spaceId) ?? {
            let created = BudgetSpaceSettings(id: spaceId, spaceId: spaceId)
            context.insert(created)
            return created
        }()

        settings.openingBalance = openingBalance
        settings.currencyCode = currencyCode.uppercased()
        settings.updatedAt = .now
        settings.updatedBy = actor
        settings.version += 1
        settings.pendingSync = true
        try context.save()
        return settings
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

    func markRecurringRuleDeletedLocal(_ rule: BudgetRecurringRule, actor: UUID?) throws {
        guard context != nil else { throw RepositoryError.missingLocalContext }
        rule.deletedAt = .now
        rule.updatedAt = .now
        rule.updatedBy = actor
        rule.version += 1
        rule.pendingSync = true
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
        guard supportsBudgetEntryExtendedSchema else {
            try await client.from("budget_entries").upsert(legacyPayload(for: entry)).execute()
            return
        }

        let payload = BudgetEntryPayload(
            id: entry.id,
            space_id: entry.spaceId,
            title: entry.title,
            kind: entry.kind,
            amount: entry.amount,
            category: entry.category,
            subcategory: entry.subcategory,
            merchant_name: entry.merchantName,
            merchant_url: entry.merchantURLString,
            icon_name: entry.iconName,
            icon_color_hex: entry.iconColorHex,
            notes: entry.notes,
            entry_date: entry.entryDate,
            is_fixed: entry.isFixed,
            is_recurring: entry.isRecurring,
            recurring_interval: entry.recurringInterval,
            created_by: entry.createdBy,
            updated_at: entry.updatedAt,
            version: entry.version,
            updated_by: entry.updatedBy,
            deleted_at: entry.deletedAt
        )

        do {
            try await client.from("budget_entries").upsert(payload).execute()
        } catch {
            guard shouldRetryBudgetEntryUpsertWithLegacySchema(error) else {
                throw error
            }

            supportsBudgetEntryExtendedSchema = false
            Log.msg("BudgetRepository detected legacy budget_entries schema. Falling back to compatibility payload.")

            try await client.from("budget_entries").upsert(legacyPayload(for: entry)).execute()
        }
    }

    private func upsertRecurringRuleRemote(_ rule: BudgetRecurringRule) async throws -> Bool {
        guard supportsRecurringRulesRemote else { return false }
        let payload = BudgetRecurringRulePayload(
            id: rule.id,
            space_id: rule.spaceId,
            title: rule.title,
            kind: rule.kind,
            amount: rule.amount,
            category: rule.category,
            subcategory: rule.subcategory,
            merchant_name: rule.merchantName,
            merchant_url: rule.merchantURLString,
            notes: rule.notes,
            cadence: rule.cadence,
            anchor_date: rule.anchorDate,
            is_fixed: rule.isFixed,
            icon_name: rule.iconName,
            icon_color_hex: rule.iconColorHex,
            is_active: rule.isActive,
            created_by: rule.createdBy,
            updated_at: rule.updatedAt,
            version: rule.version,
            updated_by: rule.updatedBy,
            deleted_at: rule.deletedAt
        )

        do {
            try await client.from("budget_recurring_rules").upsert(payload).execute()
            return true
        } catch {
            guard isMissingRemoteBudgetTable(error, tableName: "budget_recurring_rules") else {
                throw error
            }
            supportsRecurringRulesRemote = false
            Log.msg("BudgetRepository detected missing remote table budget_recurring_rules. Recurring rules will stay local until backend migration is applied.")
            return false
        }
    }

    private func upsertSpaceSettingsRemote(_ settings: BudgetSpaceSettings) async throws -> Bool {
        guard supportsSpaceSettingsRemote else { return false }
        let payload = BudgetSpaceSettingsPayload(
            id: settings.id,
            space_id: settings.spaceId,
            opening_balance: settings.openingBalance,
            currency_code: settings.currencyCode,
            updated_at: settings.updatedAt,
            version: settings.version,
            updated_by: settings.updatedBy
        )

        do {
            try await client.from("budget_space_settings").upsert(payload).execute()
            return true
        } catch {
            guard isMissingRemoteBudgetTable(error, tableName: "budget_space_settings") else {
                throw error
            }
            supportsSpaceSettingsRemote = false
            Log.msg("BudgetRepository detected missing remote table budget_space_settings. Budget settings will stay local until backend migration is applied.")
            return false
        }
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
            .order("entry_date", ascending: false)
            .execute()
            .value

        for record in remoteEntries {
            let local = try context.fetch(FetchDescriptor<BudgetEntry>(predicate: #Predicate { $0.id == record.id })).first
            if let local {
                if local.version <= record.version {
                    apply(record: record, to: local)
                }
            } else {
                let entry = BudgetEntry(
                    id: record.id,
                    spaceId: record.spaceId,
                    title: record.title,
                    kind: record.kind,
                    amount: record.amount,
                    category: record.category,
                    subcategory: record.subcategory,
                    merchantName: record.merchantName,
                    merchantURLString: record.merchantURLString,
                    iconName: record.iconName,
                    iconColorHex: record.iconColorHex,
                    notes: record.notes,
                    entryDate: record.entryDate,
                    isFixed: record.isFixed ?? false,
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

        if supportsRecurringRulesRemote {
            do {
            let remoteRules: [BudgetRecurringRuleRecord] = try await client
                .from("budget_recurring_rules")
                .select("*")
                .eq("space_id", value: spaceId)
                .order("anchor_date", ascending: true)
                .execute()
                .value

            for record in remoteRules {
                let local = try context.fetch(FetchDescriptor<BudgetRecurringRule>(predicate: #Predicate { $0.id == record.id })).first
                if let local {
                    if local.version <= record.version {
                        apply(record: record, to: local)
                    }
                } else {
                    let rule = BudgetRecurringRule(
                        id: record.id,
                        spaceId: record.spaceId,
                        title: record.title,
                        kind: record.kind,
                        amount: record.amount,
                        category: record.category,
                        subcategory: record.subcategory,
                        merchantName: record.merchantName,
                        merchantURLString: record.merchantURLString,
                        notes: record.notes,
                        cadence: record.cadence,
                        anchorDate: record.anchorDate,
                        isFixed: record.isFixed,
                        iconName: record.iconName,
                        iconColorHex: record.iconColorHex,
                        isActive: record.isActive,
                        createdBy: record.createdBy
                    )
                    rule.createdAt = record.createdAt ?? .now
                    rule.updatedAt = record.updatedAt ?? .now
                    rule.version = record.version
                    rule.updatedBy = record.updatedBy
                    rule.deletedAt = record.deletedAt
                    rule.pendingSync = false
                    context.insert(rule)
                }
            }
            } catch {
                if isMissingRemoteBudgetTable(error, tableName: "budget_recurring_rules") {
                    supportsRecurringRulesRemote = false
                    Log.msg("BudgetRepository detected missing remote table budget_recurring_rules during pull. Recurring rules remain local for now.")
                } else {
                    Log.error("BudgetRepository.pullRemoteToLocal rules skipped for spaceId=\(spaceId.uuidString): \(error.localizedDescription)")
                }
            }
        }

        if supportsSpaceSettingsRemote {
            do {
            let remoteSettings: [BudgetSpaceSettingsRecord] = try await client
                .from("budget_space_settings")
                .select("*")
                .eq("space_id", value: spaceId)
                .limit(1)
                .execute()
                .value

            if let record = remoteSettings.first {
                let local = try fetchSpaceSettingsLocal(spaceId: spaceId)
                if let local {
                    if local.version <= record.version {
                        apply(record: record, to: local)
                    }
                } else {
                    let settings = BudgetSpaceSettings(
                        id: record.id,
                        spaceId: record.spaceId,
                        openingBalance: record.openingBalance,
                        currencyCode: record.currencyCode,
                        updatedBy: record.updatedBy
                    )
                    settings.createdAt = record.createdAt ?? .now
                    settings.updatedAt = record.updatedAt ?? .now
                    settings.version = record.version
                    settings.pendingSync = false
                    context.insert(settings)
                }
            }
            } catch {
                if isMissingRemoteBudgetTable(error, tableName: "budget_space_settings") {
                    supportsSpaceSettingsRemote = false
                    Log.msg("BudgetRepository detected missing remote table budget_space_settings during pull. Space settings remain local for now.")
                } else {
                    Log.error("BudgetRepository.pullRemoteToLocal settings skipped for spaceId=\(spaceId.uuidString): \(error.localizedDescription)")
                }
            }
        }

        let remoteGoals: [BudgetGoalRecord] = try await client
            .from("budget_goals")
            .select("*")
            .eq("space_id", value: spaceId)
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

        if supportsRecurringRulesRemote {
            do {
            let pendingRules = try context.fetch(
                FetchDescriptor<BudgetRecurringRule>(predicate: #Predicate { $0.spaceId == spaceId && $0.pendingSync == true })
            )
            for rule in pendingRules {
                let didSync = try await upsertRecurringRuleRemote(rule)
                if didSync {
                    rule.pendingSync = false
                }
            }
            } catch {
                if isMissingRemoteBudgetTable(error, tableName: "budget_recurring_rules") {
                    supportsRecurringRulesRemote = false
                    Log.msg("BudgetRepository detected missing remote table budget_recurring_rules during sync. Pending recurring rules will remain local.")
                } else {
                    Log.error("BudgetRepository.syncPendingLocal rules skipped for spaceId=\(spaceId.uuidString): \(error.localizedDescription)")
                }
            }
        }

        if supportsSpaceSettingsRemote {
            do {
            let pendingSettings = try context.fetch(
                FetchDescriptor<BudgetSpaceSettings>(predicate: #Predicate { $0.spaceId == spaceId && $0.pendingSync == true })
            )
            for settings in pendingSettings {
                let didSync = try await upsertSpaceSettingsRemote(settings)
                if didSync {
                    settings.pendingSync = false
                }
            }
            } catch {
                if isMissingRemoteBudgetTable(error, tableName: "budget_space_settings") {
                    supportsSpaceSettingsRemote = false
                    Log.msg("BudgetRepository detected missing remote table budget_space_settings during sync. Pending settings will remain local.")
                } else {
                    Log.error("BudgetRepository.syncPendingLocal settings skipped for spaceId=\(spaceId.uuidString): \(error.localizedDescription)")
                }
            }
        }

        try context.save()
    }

    private func apply(record: BudgetEntryRecord, to local: BudgetEntry) {
        local.title = record.title
        local.kind = record.kind
        local.amount = record.amount
        local.category = record.category
        local.subcategory = record.subcategory
        local.merchantName = record.merchantName
        local.merchantURLString = record.merchantURLString
        local.iconName = record.iconName
        local.iconColorHex = record.iconColorHex
        local.notes = record.notes
        local.entryDate = record.entryDate
        local.isFixed = record.isFixed ?? false
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

    private func apply(record: BudgetRecurringRuleRecord, to local: BudgetRecurringRule) {
        local.title = record.title
        local.kind = record.kind
        local.amount = record.amount
        local.category = record.category
        local.subcategory = record.subcategory
        local.merchantName = record.merchantName
        local.merchantURLString = record.merchantURLString
        local.notes = record.notes
        local.cadence = record.cadence
        local.anchorDate = record.anchorDate
        local.isFixed = record.isFixed
        local.iconName = record.iconName
        local.iconColorHex = record.iconColorHex
        local.isActive = record.isActive
        local.createdBy = record.createdBy
        local.createdAt = record.createdAt ?? local.createdAt
        local.updatedAt = record.updatedAt ?? local.updatedAt
        local.version = record.version
        local.updatedBy = record.updatedBy
        local.deletedAt = record.deletedAt
        local.pendingSync = false
    }

    private func apply(record: BudgetSpaceSettingsRecord, to local: BudgetSpaceSettings) {
        local.id = record.id
        local.spaceId = record.spaceId
        local.openingBalance = record.openingBalance
        local.currencyCode = record.currencyCode
        local.createdAt = record.createdAt ?? local.createdAt
        local.updatedAt = record.updatedAt ?? local.updatedAt
        local.version = record.version
        local.updatedBy = record.updatedBy
        local.pendingSync = false
    }

    private func shouldRetryBudgetEntryUpsertWithLegacySchema(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        guard message.contains("budget_entries") else { return false }

        let unsupportedColumns = [
            "is_fixed",
            "subcategory",
            "merchant_name",
            "merchant_url"
        ]

        return unsupportedColumns.contains(where: message.contains)
            || (message.contains("schema cache") && message.contains("column"))
    }

    private func isMissingRemoteBudgetTable(_ error: Error, tableName: String) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains(tableName.lowercased())
            && message.contains("schema cache")
            && message.contains("could not find the table")
    }

    private func legacyPayload(for entry: BudgetEntry) -> BudgetEntryLegacyPayload {
        BudgetEntryLegacyPayload(
            id: entry.id,
            space_id: entry.spaceId,
            title: entry.title,
            kind: entry.kind,
            amount: entry.amount,
            category: entry.category,
            icon_name: entry.iconName,
            icon_color_hex: entry.iconColorHex,
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
    }
}
