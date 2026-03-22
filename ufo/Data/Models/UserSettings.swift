import Foundation
import SwiftData

@Model
final class UserSettings {
    @Attribute(.unique) var userId: UUID
    var defaultSpaceId: UUID?
    var homeWidgetsConfig: String
    var budgetCustomCategories: String
    var budgetCategoryLimits: String
    var appFlags: String
    var createdAt: Date
    var updatedAt: Date
    var version: Int
    var pendingSync: Bool

    init(
        userId: UUID,
        defaultSpaceId: UUID? = nil,
        homeWidgetsConfig: String = "[]",
        budgetCustomCategories: String = "[]",
        budgetCategoryLimits: String = "[]",
        appFlags: String = "{}"
    ) {
        self.userId = userId
        self.defaultSpaceId = defaultSpaceId
        self.homeWidgetsConfig = homeWidgetsConfig
        self.budgetCustomCategories = budgetCustomCategories
        self.budgetCategoryLimits = budgetCategoryLimits
        self.appFlags = appFlags
        self.createdAt = .now
        self.updatedAt = .now
        self.version = 1
        self.pendingSync = false
    }
}

extension UserSettings {
    func decodeHomeWidgets() -> [HomeWidgetPreference] {
        decode([HomeWidgetPreference].self, from: homeWidgetsConfig) ?? []
    }

    func encodeHomeWidgets(_ value: [HomeWidgetPreference]) {
        homeWidgetsConfig = encode(value, fallback: "[]")
    }

    func decodeBudgetCustomCategories() -> [String] {
        decode([String].self, from: budgetCustomCategories) ?? []
    }

    func encodeBudgetCustomCategories(_ value: [String]) {
        budgetCustomCategories = encode(value, fallback: "[]")
    }

    func decodeBudgetCategoryLimits() -> [BudgetCategoryLimitPreference] {
        decode([BudgetCategoryLimitPreference].self, from: budgetCategoryLimits) ?? []
    }

    func encodeBudgetCategoryLimits(_ value: [BudgetCategoryLimitPreference]) {
        budgetCategoryLimits = encode(value, fallback: "[]")
    }

    func decodeAppFlags() -> [String: Bool] {
        decode([String: Bool].self, from: appFlags) ?? [:]
    }

    func encodeAppFlags(_ value: [String: Bool]) {
        appFlags = encode(value, fallback: "{}")
    }

    private func decode<T: Decodable>(_ type: T.Type, from string: String) -> T? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func encode<T: Encodable>(_ value: T, fallback: String) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return fallback
        }
        return string
    }
}
