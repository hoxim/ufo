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

enum AppLanguagePreference: String, CaseIterable, Identifiable {
    case system
    case english
    case polish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: String(localized: "settings.localization.language.system")
        case .english: "English"
        case .polish: "Polski"
        }
    }

    var localeIdentifier: String? {
        switch self {
        case .system: nil
        case .english: "en"
        case .polish: "pl"
        }
    }
}

enum AppCurrencyPreference: String, CaseIterable, Identifiable {
    case pln = "PLN"
    case eur = "EUR"
    case usd = "USD"
    case gbp = "GBP"
    case chf = "CHF"
    case czk = "CZK"
    case sek = "SEK"
    case nok = "NOK"
    case dkk = "DKK"

    var id: String { rawValue }
    var currencyCode: String { rawValue }

    var title: String {
        let locale = Locale.current
        let localizedName = locale.localizedString(forCurrencyCode: rawValue) ?? rawValue
        return "\(rawValue) - \(localizedName)"
    }
}

enum AppMeasurementSystemPreference: String, CaseIterable, Identifiable {
    case system
    case metric
    case imperial

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: String(localized: "settings.localization.measurement.system")
        case .metric: String(localized: "settings.localization.measurement.metric")
        case .imperial: String(localized: "settings.localization.measurement.imperial")
        }
    }
}

enum AppWeightUnitPreference: String, CaseIterable, Identifiable {
    case system
    case kilograms
    case pounds

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: String(localized: "settings.localization.weight.system")
        case .kilograms: String(localized: "settings.localization.weight.kilograms")
        case .pounds: String(localized: "settings.localization.weight.pounds")
        }
    }
}

enum NoteEditorFontDesign: String, CaseIterable, Identifiable {
    case system
    case rounded
    case serif
    case monospaced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: String(localized: "settings.notes.fontDesign.system")
        case .rounded: String(localized: "settings.notes.fontDesign.rounded")
        case .serif: String(localized: "settings.notes.fontDesign.serif")
        case .monospaced: String(localized: "settings.notes.fontDesign.monospaced")
        }
    }
}

enum NoteEditorFontSizePreference: String, CaseIterable, Identifiable {
    case compact
    case standard
    case large
    case extraLarge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact: String(localized: "settings.notes.fontSize.compact")
        case .standard: String(localized: "settings.notes.fontSize.standard")
        case .large: String(localized: "settings.notes.fontSize.large")
        case .extraLarge: String(localized: "settings.notes.fontSize.extraLarge")
        }
    }

    var phoneBodySize: Double {
        switch self {
        case .compact: 17
        case .standard: 19
        case .large: 21
        case .extraLarge: 23
        }
    }

    var padBodySize: Double { phoneBodySize }

    var macBodySize: Double {
        switch self {
        case .compact: 16
        case .standard: 18
        case .large: 20
        case .extraLarge: 22
        }
    }

    func headingSize(for bodySize: Double) -> Double {
        bodySize + 11
    }
}

enum AppWeekStartPreference: String, CaseIterable, Identifiable {
    case system
    case monday
    case sunday

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: String(localized: "settings.localization.weekStart.system")
        case .monday: String(localized: "settings.localization.weekStart.monday")
        case .sunday: String(localized: "settings.localization.weekStart.sunday")
        }
    }
}

@MainActor
@Observable
final class AppPreferences {
    static let shared = AppPreferences()

    nonisolated static let noteEditorFontDesignKey = "settings_notes_font_design"
    nonisolated static let noteEditorFontSizeKey = "settings_notes_font_size"

    private let userDefaults: UserDefaults
    private let productTierKey = "app_product_tier"
    private let autoSyncEnabledKey = "settings_auto_sync_enabled"
    private let appLanguageKey = "settings_app_language"
    private let defaultCurrencyKey = "settings_default_currency"
    private let measurementSystemKey = "settings_measurement_system"
    private let weightUnitKey = "settings_weight_unit"
    private let weekStartKey = "settings_week_start"
    private let biometricUnlockEnabledKey = "settings_biometric_unlock_enabled"
    private let homeWidgetsKey = "home_widgets_configuration_v1"
    private let budgetDashboardWidgetsKey = "budget_dashboard_widgets_configuration_v1"
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

    var appLanguage: AppLanguagePreference {
        didSet {
            userDefaults.set(appLanguage.rawValue, forKey: appLanguageKey)
        }
    }

    var defaultCurrency: AppCurrencyPreference {
        didSet {
            userDefaults.set(defaultCurrency.rawValue, forKey: defaultCurrencyKey)
        }
    }

    var measurementSystem: AppMeasurementSystemPreference {
        didSet {
            userDefaults.set(measurementSystem.rawValue, forKey: measurementSystemKey)
        }
    }

    var weightUnit: AppWeightUnitPreference {
        didSet {
            userDefaults.set(weightUnit.rawValue, forKey: weightUnitKey)
        }
    }

    var weekStart: AppWeekStartPreference {
        didSet {
            userDefaults.set(weekStart.rawValue, forKey: weekStartKey)
        }
    }

    var noteEditorFontDesign: NoteEditorFontDesign {
        didSet {
            userDefaults.set(noteEditorFontDesign.rawValue, forKey: Self.noteEditorFontDesignKey)
        }
    }

    var noteEditorFontSize: NoteEditorFontSizePreference {
        didSet {
            userDefaults.set(noteEditorFontSize.rawValue, forKey: Self.noteEditorFontSizeKey)
        }
    }

    var biometricUnlockEnabled: Bool {
        didSet {
            userDefaults.set(biometricUnlockEnabled, forKey: biometricUnlockEnabledKey)
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

    var defaultCurrencyCode: String {
        defaultCurrency.currencyCode
    }

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let storedTier = userDefaults.string(forKey: productTierKey)
        self.productTier = AppProductTier(rawValue: storedTier ?? "") ?? .premiumOnline
        self.autoSyncEnabled = userDefaults.object(forKey: autoSyncEnabledKey) as? Bool ?? true
        self.appLanguage = AppLanguagePreference(rawValue: userDefaults.string(forKey: appLanguageKey) ?? "") ?? .system
        self.defaultCurrency = AppCurrencyPreference(rawValue: userDefaults.string(forKey: defaultCurrencyKey) ?? "") ?? .pln
        self.measurementSystem = AppMeasurementSystemPreference(rawValue: userDefaults.string(forKey: measurementSystemKey) ?? "") ?? .system
        self.weightUnit = AppWeightUnitPreference(rawValue: userDefaults.string(forKey: weightUnitKey) ?? "") ?? .system
        self.weekStart = AppWeekStartPreference(rawValue: userDefaults.string(forKey: weekStartKey) ?? "") ?? .system
        self.noteEditorFontDesign = NoteEditorFontDesign(rawValue: userDefaults.string(forKey: Self.noteEditorFontDesignKey) ?? "") ?? .system
        self.noteEditorFontSize = NoteEditorFontSizePreference(rawValue: userDefaults.string(forKey: Self.noteEditorFontSizeKey) ?? "") ?? .standard
        self.biometricUnlockEnabled = userDefaults.object(forKey: biometricUnlockEnabledKey) as? Bool ?? false
        self.homeWidgets = Self.loadHomeWidgets(from: userDefaults, key: homeWidgetsKey)
        self.budgetDashboardWidgets = Self.loadBudgetDashboardWidgets(from: userDefaults, key: budgetDashboardWidgetsKey)
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
