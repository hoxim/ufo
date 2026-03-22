import Foundation
import SwiftData
import Supabase

@MainActor
final class UserSettingsRepository {
    private let client: SupabaseClient
    private let context: ModelContext?

    init(client: SupabaseClient, context: ModelContext? = nil) {
        self.client = client
        self.context = context
    }

    struct UserSettingsRecord: Codable {
        let userId: UUID
        let defaultSpaceId: UUID?
        let homeWidgetsConfig: [HomeWidgetPreference]
        let budgetCustomCategories: [String]
        let budgetCategoryLimits: [BudgetCategoryLimitPreference]
        let appFlags: [String: Bool]
        let createdAt: Date?
        let updatedAt: Date?
        let version: Int

        enum CodingKeys: String, CodingKey {
            case version
            case userId = "user_id"
            case defaultSpaceId = "default_space_id"
            case homeWidgetsConfig = "home_widgets_config"
            case budgetCustomCategories = "budget_custom_categories"
            case budgetCategoryLimits = "budget_category_limits"
            case appFlags = "app_flags"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }

    private struct UserSettingsPayload: Encodable {
        let user_id: UUID
        let default_space_id: UUID?
        let home_widgets_config: [HomeWidgetPreference]
        let budget_custom_categories: [String]
        let budget_category_limits: [BudgetCategoryLimitPreference]
        let app_flags: [String: Bool]
        let version: Int
    }

    func fetchLocal(userId: UUID) throws -> UserSettings? {
        guard let context else { return nil }
        return try context.fetch(
            FetchDescriptor<UserSettings>(
                predicate: #Predicate { $0.userId == userId }
            )
        ).first
    }

    @discardableResult
    func upsertLocal(
        userId: UUID,
        defaultSpaceId: UUID?,
        homeWidgets: [HomeWidgetPreference],
        budgetCustomCategories: [String],
        budgetCategoryLimits: [BudgetCategoryLimitPreference],
        appFlags: [String: Bool]
    ) throws -> UserSettings {
        guard let context else { throw RepositoryError.missingLocalContext }

        let settings = try fetchLocal(userId: userId) ?? UserSettings(userId: userId)
        settings.defaultSpaceId = defaultSpaceId
        settings.encodeHomeWidgets(homeWidgets)
        settings.encodeBudgetCustomCategories(budgetCustomCategories)
        settings.encodeBudgetCategoryLimits(budgetCategoryLimits)
        settings.encodeAppFlags(appFlags)
        settings.updatedAt = .now
        settings.version += 1
        settings.pendingSync = true

        if settings.modelContext == nil {
            context.insert(settings)
        }

        try context.save()
        return settings
    }

    func pullRemoteToLocal(userId: UUID) async throws {
        guard let context else { return }

        let records: [UserSettingsRecord] = try await client
            .from("user_settings")
            .select("*")
            .eq("user_id", value: userId)
            .execute()
            .value

        let record = records.first
        guard let record else { return }

        let local = try fetchLocal(userId: userId) ?? UserSettings(userId: userId)
        if local.modelContext == nil {
            context.insert(local)
        }

        if local.version <= record.version || local.pendingSync == false {
            local.defaultSpaceId = record.defaultSpaceId
            local.encodeHomeWidgets(record.homeWidgetsConfig)
            local.encodeBudgetCustomCategories(record.budgetCustomCategories)
            local.encodeBudgetCategoryLimits(record.budgetCategoryLimits)
            local.encodeAppFlags(record.appFlags)
            local.createdAt = record.createdAt ?? local.createdAt
            local.updatedAt = record.updatedAt ?? local.updatedAt
            local.version = record.version
            local.pendingSync = false
            try context.save()
        }
    }

    func syncPending(userId: UUID) async throws {
        guard let settings = try fetchLocal(userId: userId) else { return }
        guard settings.pendingSync else { return }

        let payload = UserSettingsPayload(
            user_id: settings.userId,
            default_space_id: settings.defaultSpaceId,
            home_widgets_config: settings.decodeHomeWidgets(),
            budget_custom_categories: settings.decodeBudgetCustomCategories(),
            budget_category_limits: settings.decodeBudgetCategoryLimits(),
            app_flags: settings.decodeAppFlags(),
            version: settings.version
        )

        try await client
            .from("user_settings")
            .upsert(payload)
            .execute()

        settings.pendingSync = false
        try context?.save()
    }
}
