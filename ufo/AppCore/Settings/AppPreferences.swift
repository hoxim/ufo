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
        case .notes, .summary, .budget:
            .full
        case .missions, .lists, .incidents, .routines:
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

struct BudgetCategoryLimitPreference: Codable, Identifiable, Equatable, Hashable {
    var category: String
    var amount: Double

    var id: String { category }
}

enum BudgetDashboardWidgetKind: String, CaseIterable, Codable, Identifiable {
    case overview
    case cashFlow
    case runningBalance
    case categoryBreakdown
    case upcomingRecurring

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .cashFlow: "Cash Flow"
        case .runningBalance: "Running Balance"
        case .categoryBreakdown: "Categories"
        case .upcomingRecurring: "Upcoming"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "chart.bar.doc.horizontal"
        case .cashFlow: "chart.bar.xaxis"
        case .runningBalance: "chart.line.uptrend.xyaxis"
        case .categoryBreakdown: "chart.pie"
        case .upcomingRecurring: "calendar.badge.clock"
        }
    }

    var supportedSpans: [HomeWidgetSpan] {
        switch self {
        case .cashFlow, .runningBalance:
            [.full]
        case .overview, .categoryBreakdown, .upcomingRecurring:
            [.half, .full]
        }
    }

    var defaultSpan: HomeWidgetSpan {
        switch self {
        case .cashFlow, .runningBalance:
            .full
        case .overview, .categoryBreakdown, .upcomingRecurring:
            .half
        }
    }
}

struct BudgetDashboardWidgetPreference: Codable, Identifiable, Equatable {
    var kind: BudgetDashboardWidgetKind
    var isVisible: Bool
    var span: HomeWidgetSpan

    var id: BudgetDashboardWidgetKind { kind }
}

enum AutoLockTimeout: Int, CaseIterable, Identifiable {
    case immediately = 0
    case oneMinute = 60
    case fiveMinutes = 300
    case never = -1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .immediately: String(localized: "settings.security.autoLock.immediately")
        case .oneMinute:   String(localized: "settings.security.autoLock.oneMinute")
        case .fiveMinutes: String(localized: "settings.security.autoLock.fiveMinutes")
        case .never:       String(localized: "settings.security.autoLock.never")
        }
    }
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
    private let budgetDashboardWidgetsKey = "budget_dashboard_widgets_configuration_v1"
    private let budgetCustomCategoriesKey = "budget_custom_categories_v1"
    private let budgetCategoryLimitsKey = "budget_category_limits_v1"
    private let biometricLockEnabledKey = "security_biometric_lock_enabled"
    private let autoLockTimeoutKey = "security_auto_lock_timeout"

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
            let normalized = Self.normalizedHomeWidgets(homeWidgets)
            guard normalized == homeWidgets else {
                homeWidgets = normalized
                return
            }
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

    var budgetDashboardWidgets: [BudgetDashboardWidgetPreference] {
        didSet {
            let normalized = Self.normalizedBudgetDashboardWidgets(budgetDashboardWidgets)
            guard normalized == budgetDashboardWidgets else {
                budgetDashboardWidgets = normalized
                return
            }
            persistBudgetDashboardWidgets()
        }
    }

    var biometricLockEnabled: Bool {
        didSet {
            userDefaults.set(biometricLockEnabled, forKey: biometricLockEnabledKey)
        }
    }

    var autoLockTimeout: AutoLockTimeout {
        didSet {
            userDefaults.set(autoLockTimeout.rawValue, forKey: autoLockTimeoutKey)
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
        self.budgetDashboardWidgets = Self.loadBudgetDashboardWidgets(from: userDefaults, key: budgetDashboardWidgetsKey)
        self.budgetCustomCategories = Self.loadCodable([String].self, from: userDefaults, key: budgetCustomCategoriesKey) ?? []
        self.budgetCategoryLimits = Self.loadCodable([BudgetCategoryLimitPreference].self, from: userDefaults, key: budgetCategoryLimitsKey) ?? []
        self.budgetCustomCategories = Self.normalizedBudgetCategories(budgetCustomCategories)
        self.budgetCategoryLimits = Self.normalizedBudgetCategoryLimits(budgetCategoryLimits)
        self.biometricLockEnabled = userDefaults.object(forKey: biometricLockEnabledKey) as? Bool ?? false
        let timeoutRaw = userDefaults.object(forKey: autoLockTimeoutKey) as? Int ?? AutoLockTimeout.immediately.rawValue
        self.autoLockTimeout = AutoLockTimeout(rawValue: timeoutRaw) ?? .immediately

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

    func updateBudgetDashboardWidget(_ kind: BudgetDashboardWidgetKind, mutate: (inout BudgetDashboardWidgetPreference) -> Void) {
        guard let index = budgetDashboardWidgets.firstIndex(where: { $0.kind == kind }) else { return }
        mutate(&budgetDashboardWidgets[index])
        budgetDashboardWidgets = Self.normalizedBudgetDashboardWidgets(budgetDashboardWidgets)
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

    private func persistBudgetDashboardWidgets() {
        persistCodable(budgetDashboardWidgets, key: budgetDashboardWidgetsKey)
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

    private static func loadBudgetDashboardWidgets(from userDefaults: UserDefaults, key: String) -> [BudgetDashboardWidgetPreference] {
        guard
            let data = userDefaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode([BudgetDashboardWidgetPreference].self, from: data)
        else {
            return defaultBudgetDashboardWidgets
        }

        return normalizedBudgetDashboardWidgets(decoded)
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

        for kind in preferredHomeWidgetOrder where !seenKinds.contains(kind) {
            normalized.append(
                HomeWidgetPreference(
                    kind: kind,
                    isVisible: kind.defaultVisibility,
                    span: kind.defaultSpan
                )
            )
        }

        if normalized == legacyDefaultHomeWidgets || normalized == legacyPreferredOrderHomeWidgets {
            return preferredHomeWidgetDefaults
        }

        let nonSummaryWidgets = normalized.filter { $0.kind != .summary }
        let summaryWidgets = normalized.filter { $0.kind == .summary }
        return nonSummaryWidgets + summaryWidgets
    }

    private static var defaultHomeWidgets: [HomeWidgetPreference] {
        preferredHomeWidgetDefaults
    }

    private static func normalizedBudgetDashboardWidgets(_ widgets: [BudgetDashboardWidgetPreference]) -> [BudgetDashboardWidgetPreference] {
        var normalized: [BudgetDashboardWidgetPreference] = []
        var seenKinds = Set<BudgetDashboardWidgetKind>()

        for widget in widgets {
            guard !seenKinds.contains(widget.kind) else { continue }
            seenKinds.insert(widget.kind)

            let supportedSpans = widget.kind.supportedSpans
            normalized.append(
                BudgetDashboardWidgetPreference(
                    kind: widget.kind,
                    isVisible: widget.isVisible,
                    span: supportedSpans.contains(widget.span) ? widget.span : widget.kind.defaultSpan
                )
            )
        }

        for kind in preferredBudgetDashboardWidgetOrder where !seenKinds.contains(kind) {
            normalized.append(BudgetDashboardWidgetPreference(kind: kind, isVisible: true, span: kind.defaultSpan))
        }

        return normalized
    }

    private static var preferredHomeWidgetOrder: [HomeWidgetKind] {
        [.notes, .missions, .lists, .incidents, .routines, .budget, .summary]
    }

    private static var preferredHomeWidgetDefaults: [HomeWidgetPreference] {
        preferredHomeWidgetOrder.map { kind in
            HomeWidgetPreference(kind: kind, isVisible: kind.defaultVisibility, span: kind.defaultSpan)
        }
    }

    private static var preferredBudgetDashboardWidgetOrder: [BudgetDashboardWidgetKind] {
        [.overview, .cashFlow, .runningBalance, .categoryBreakdown, .upcomingRecurring]
    }

    private static var defaultBudgetDashboardWidgets: [BudgetDashboardWidgetPreference] {
        preferredBudgetDashboardWidgetOrder.map { kind in
            BudgetDashboardWidgetPreference(kind: kind, isVisible: true, span: kind.defaultSpan)
        }
    }

    private static var legacyPreferredOrderHomeWidgets: [HomeWidgetPreference] {
        [
            HomeWidgetPreference(kind: .notes, isVisible: true, span: .half),
            HomeWidgetPreference(kind: .missions, isVisible: true, span: .full),
            HomeWidgetPreference(kind: .lists, isVisible: true, span: .half),
            HomeWidgetPreference(kind: .incidents, isVisible: true, span: .half),
            HomeWidgetPreference(kind: .routines, isVisible: true, span: .half),
            HomeWidgetPreference(kind: .budget, isVisible: true, span: .full),
            HomeWidgetPreference(kind: .summary, isVisible: true, span: .full)
        ]
    }

    private static var legacyDefaultHomeWidgets: [HomeWidgetPreference] {
        [
            HomeWidgetPreference(kind: .missions, isVisible: true, span: .full),
            HomeWidgetPreference(kind: .lists, isVisible: true, span: .half),
            HomeWidgetPreference(kind: .notes, isVisible: true, span: .half),
            HomeWidgetPreference(kind: .incidents, isVisible: true, span: .half),
            HomeWidgetPreference(kind: .routines, isVisible: true, span: .half),
            HomeWidgetPreference(kind: .summary, isVisible: true, span: .full),
            HomeWidgetPreference(kind: .budget, isVisible: true, span: .full)
        ]
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
