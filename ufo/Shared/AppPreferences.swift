import Foundation
import Observation

extension Notification.Name {
    static let homeWidgetsDataDidChange = Notification.Name("home_widgets_data_did_change")
}

@MainActor
func notifyHomeWidgetsDataDidChange() {
    NotificationCenter.default.post(name: .homeWidgetsDataDidChange, object: nil)
}

enum HomeWidgetSpan: String, CaseIterable, Codable, Identifiable {
    case half
    case full

    var id: String { rawValue }

    var title: String {
        switch self {
        case .half: "Half"
        case .full: "Full"
        }
    }
}

enum HomeWidgetKind: String, CaseIterable, Codable, Identifiable {
    case missions
    case lists
    case notes
    case incidents
    case routines
    case summary
    case budget

    var id: String { rawValue }

    var title: String {
        switch self {
        case .missions: "Missions"
        case .lists: "Lists"
        case .notes: "Notes"
        case .incidents: "Incidents"
        case .routines: "Routines"
        case .summary: "Today Summary"
        case .budget: "Budget"
        }
    }

    var systemImage: String {
        switch self {
        case .missions: "target"
        case .lists: "checklist"
        case .notes: "note.text"
        case .incidents: "bolt.horizontal"
        case .routines: "clock.arrow.circlepath"
        case .summary: "square.grid.2x2"
        case .budget: "dollarsign.circle"
        }
    }

    var supportedSpans: [HomeWidgetSpan] {
        switch self {
        case .summary, .budget:
            [.full]
        case .missions, .lists, .notes, .incidents, .routines:
            [.half, .full]
        }
    }

    var defaultSpan: HomeWidgetSpan {
        switch self {
        case .missions, .summary, .budget:
            .full
        case .lists, .notes, .incidents, .routines:
            .half
        }
    }

    var defaultVisibility: Bool {
        true
    }
}

struct HomeWidgetPreference: Codable, Identifiable, Equatable {
    var kind: HomeWidgetKind
    var isVisible: Bool
    var span: HomeWidgetSpan

    var id: HomeWidgetKind { kind }
}

struct BudgetCategoryLimitPreference: Codable, Identifiable, Equatable {
    var category: String
    var amount: Double

    var id: String { category }
}

enum AppProductTier: String, CaseIterable, Identifiable {
    case standardOffline
    case premiumOnline

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standardOffline: "Standard Offline"
        case .premiumOnline: "Premium Online"
        }
    }

    var summary: String {
        switch self {
        case .standardOffline: "Lokalne dane, bez chmury i bez współdzielenia."
        case .premiumOnline: "Synchronizacja, współdzielenie i funkcje grupowe online."
        }
    }
}

@MainActor
@Observable
final class AppPreferences {
    static let shared = AppPreferences()

    private let userDefaults: UserDefaults
    private let productTierKey = "app_product_tier"
    private let autoSyncEnabledKey = "settings_auto_sync_enabled"
    private let homeWidgetsKey = "home_widgets_configuration_v1"
    private let budgetCustomCategoriesKey = "budget_custom_categories_v1"
    private let budgetCategoryLimitsKey = "budget_category_limits_v1"

    var productTier: AppProductTier {
        didSet {
            userDefaults.set(productTier.rawValue, forKey: productTierKey)
            if !supportsCloudFeatures {
                autoSyncEnabled = false
            }
        }
    }

    var autoSyncEnabled: Bool {
        didSet {
            userDefaults.set(autoSyncEnabled, forKey: autoSyncEnabledKey)
        }
    }

    var homeWidgets: [HomeWidgetPreference] {
        didSet {
            persistHomeWidgets()
        }
    }

    var budgetCustomCategories: [String] {
        didSet {
            let normalized = Self.normalizedBudgetCategories(budgetCustomCategories)
            guard normalized == budgetCustomCategories else {
                budgetCustomCategories = normalized
                return
            }
            persistBudgetCustomCategories()
        }
    }

    var budgetCategoryLimits: [BudgetCategoryLimitPreference] {
        didSet {
            let normalized = Self.normalizedBudgetCategoryLimits(budgetCategoryLimits)
            guard normalized == budgetCategoryLimits else {
                budgetCategoryLimits = normalized
                return
            }
            persistBudgetCategoryLimits()
        }
    }

    var supportsCloudFeatures: Bool {
        productTier == .premiumOnline
    }

    var isCloudSyncEnabled: Bool {
        supportsCloudFeatures && autoSyncEnabled
    }

    var allowsSharedSpaces: Bool {
        supportsCloudFeatures
    }

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let storedTier = userDefaults.string(forKey: productTierKey)
        self.productTier = AppProductTier(rawValue: storedTier ?? "") ?? .premiumOnline
        self.autoSyncEnabled = userDefaults.object(forKey: autoSyncEnabledKey) as? Bool ?? true
        self.homeWidgets = Self.loadHomeWidgets(from: userDefaults, key: homeWidgetsKey)
        self.budgetCustomCategories = Self.loadCodable([String].self, from: userDefaults, key: budgetCustomCategoriesKey) ?? []
        self.budgetCategoryLimits = Self.loadCodable([BudgetCategoryLimitPreference].self, from: userDefaults, key: budgetCategoryLimitsKey) ?? []
        self.budgetCustomCategories = Self.normalizedBudgetCategories(budgetCustomCategories)
        self.budgetCategoryLimits = Self.normalizedBudgetCategoryLimits(budgetCategoryLimits)

        if !supportsCloudFeatures {
            self.autoSyncEnabled = false
        }
    }

    func updateHomeWidget(_ kind: HomeWidgetKind, mutate: (inout HomeWidgetPreference) -> Void) {
        guard let index = homeWidgets.firstIndex(where: { $0.kind == kind }) else { return }
        mutate(&homeWidgets[index])
        homeWidgets = Self.normalizedHomeWidgets(homeWidgets)
    }

    func addBudgetCustomCategory(_ value: String) {
        budgetCustomCategories.append(value)
    }

    func removeBudgetCustomCategory(_ value: String) {
        budgetCustomCategories.removeAll { $0.caseInsensitiveCompare(value) == .orderedSame }
        removeBudgetCategoryLimit(category: value)
    }

    func setBudgetCategoryLimit(category: String, amount: Double) {
        let cleanCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanCategory.isEmpty else { return }

        if let index = budgetCategoryLimits.firstIndex(where: { $0.category.caseInsensitiveCompare(cleanCategory) == .orderedSame }) {
            budgetCategoryLimits[index].category = cleanCategory
            budgetCategoryLimits[index].amount = amount
        } else {
            budgetCategoryLimits.append(BudgetCategoryLimitPreference(category: cleanCategory, amount: amount))
        }

        budgetCategoryLimits = Self.normalizedBudgetCategoryLimits(budgetCategoryLimits)
    }

    func removeBudgetCategoryLimit(category: String) {
        budgetCategoryLimits.removeAll { $0.category.caseInsensitiveCompare(category) == .orderedSame }
    }

    private func persistHomeWidgets() {
        do {
            let data = try JSONEncoder().encode(homeWidgets)
            userDefaults.set(data, forKey: homeWidgetsKey)
        } catch {
            assertionFailure("Failed to persist home widget preferences: \(error)")
        }
    }

    private func persistBudgetCustomCategories() {
        persistCodable(budgetCustomCategories, key: budgetCustomCategoriesKey)
    }

    private func persistBudgetCategoryLimits() {
        persistCodable(budgetCategoryLimits, key: budgetCategoryLimitsKey)
    }

    private func persistCodable<T: Encodable>(_ value: T, key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            userDefaults.set(data, forKey: key)
        } catch {
            assertionFailure("Failed to persist \(key): \(error)")
        }
    }

    private static func loadCodable<T: Decodable>(_ type: T.Type, from userDefaults: UserDefaults, key: String) -> T? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func loadHomeWidgets(from userDefaults: UserDefaults, key: String) -> [HomeWidgetPreference] {
        guard
            let data = userDefaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode([HomeWidgetPreference].self, from: data)
        else {
            return defaultHomeWidgets
        }

        return normalizedHomeWidgets(decoded)
    }

    private static func normalizedHomeWidgets(_ widgets: [HomeWidgetPreference]) -> [HomeWidgetPreference] {
        var normalized: [HomeWidgetPreference] = []
        var seenKinds = Set<HomeWidgetKind>()

        for widget in widgets {
            guard !seenKinds.contains(widget.kind) else { continue }
            seenKinds.insert(widget.kind)

            let supportedSpans = widget.kind.supportedSpans
            normalized.append(
                HomeWidgetPreference(
                    kind: widget.kind,
                    isVisible: widget.isVisible,
                    span: supportedSpans.contains(widget.span) ? widget.span : widget.kind.defaultSpan
                )
            )
        }

        for kind in HomeWidgetKind.allCases where !seenKinds.contains(kind) {
            normalized.append(
                HomeWidgetPreference(
                    kind: kind,
                    isVisible: kind.defaultVisibility,
                    span: kind.defaultSpan
                )
            )
        }

        return normalized
    }

    private static var defaultHomeWidgets: [HomeWidgetPreference] {
        HomeWidgetKind.allCases.map {
            HomeWidgetPreference(kind: $0, isVisible: $0.defaultVisibility, span: $0.defaultSpan)
        }
    }

    private static func normalizedBudgetCategories(_ categories: [String]) -> [String] {
        var normalized: [String] = []
        var seen = Set<String>()

        for category in categories {
            let clean = category.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { continue }
            let key = clean.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            guard seen.insert(key).inserted else { continue }
            normalized.append(clean)
        }

        return normalized.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private static func normalizedBudgetCategoryLimits(_ limits: [BudgetCategoryLimitPreference]) -> [BudgetCategoryLimitPreference] {
        var normalized: [BudgetCategoryLimitPreference] = []
        var seen = Set<String>()

        for limit in limits {
            let clean = limit.category.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { continue }
            let key = clean.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            guard seen.insert(key).inserted else { continue }
            normalized.append(BudgetCategoryLimitPreference(category: clean, amount: max(limit.amount, 0)))
        }

        return normalized.sorted { $0.category.localizedCaseInsensitiveCompare($1.category) == .orderedAscending }
    }
}
