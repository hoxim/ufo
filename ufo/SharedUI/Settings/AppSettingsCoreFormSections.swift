#if os(iOS) || os(macOS)

import CoreLocation
import LocalAuthentication
import SwiftUI
import UserNotifications

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct AppSettingsCoreFormSections: View {
    @Environment(AppPreferences.self) private var appPreferences
    @AppStorage("settings_space_limit") private var spaceLimit: Int = 5
    @AppStorage("settings_default_space_type") private var defaultSpaceType: String = SpaceType.personal.rawValue
    @AppStorage("settings_location_sharing_enabled") private var locationSharingEnabled: Bool = false
    @State private var locationPermissionStatus = SettingsPermissionStatus.unknown
    @State private var notificationPermissionStatus = SettingsPermissionStatus.unknown
    @State private var biometricAvailability = SettingsBiometricAvailability.current()

    var body: some View {
        Group {
            planSection
            generalSection
            localizationSection
            defaultSpaceSection
            notesSection
            privacySection
            permissionsSection
            securitySection
        }
        .onAppear {
            refreshDerivedState()
        }
    }

    private var planSection: some View {
        Section("settings.section.appPlan") {
            Picker("settings.productTier.label", selection: productTierBinding) {
                ForEach(AppProductTier.allCases) { tier in
                    Text(tier.title).tag(tier)
                }
            }

            Text(appPreferences.productTier.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var generalSection: some View {
        Section("settings.section.general") {
            Stepper("\(String(localized: "settings.general.spaceLimit")): \(spaceLimit)", value: $spaceLimit, in: 1...30)
            Toggle("settings.general.autoSync", isOn: autoSyncBinding)
                .disabled(!appPreferences.supportsCloudFeatures)
        }
    }

    private var localizationSection: some View {
        Section("settings.section.localization") {
            Picker("settings.localization.language", selection: appLanguageBinding) {
                ForEach(AppLanguagePreference.allCases) { language in
                    Text(language.title).tag(language)
                }
            }

            Picker("settings.localization.currency", selection: defaultCurrencyBinding) {
                ForEach(AppCurrencyPreference.allCases) { currency in
                    Text(currency.title).tag(currency)
                }
            }

            Picker("settings.localization.measurement", selection: measurementSystemBinding) {
                ForEach(AppMeasurementSystemPreference.allCases) { system in
                    Text(system.title).tag(system)
                }
            }

            Picker("settings.localization.weight", selection: weightUnitBinding) {
                ForEach(AppWeightUnitPreference.allCases) { unit in
                    Text(unit.title).tag(unit)
                }
            }

            Picker("settings.localization.weekStart", selection: weekStartBinding) {
                ForEach(AppWeekStartPreference.allCases) { weekStart in
                    Text(weekStart.title).tag(weekStart)
                }
            }

            Text("settings.localization.note")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var defaultSpaceSection: some View {
        Section("settings.section.defaultSpace") {
            Picker("settings.defaultSpace.type", selection: $defaultSpaceType) {
                Text("settings.defaultSpace.private").tag(SpaceType.personal.rawValue)
                Text("settings.defaultSpace.shared").tag(SpaceType.shared.rawValue)
            }
            .disabled(!appPreferences.allowsSharedSpaces)
        }
    }

    private var notesSection: some View {
        Section("settings.section.notes") {
            Picker("settings.notes.fontDesign", selection: noteFontDesignBinding) {
                ForEach(NoteEditorFontDesign.allCases) { design in
                    Text(design.title).tag(design)
                }
            }

            Picker("settings.notes.fontSize", selection: noteFontSizeBinding) {
                ForEach(NoteEditorFontSizePreference.allCases) { size in
                    Text(size.title).tag(size)
                }
            }

            Text("settings.notes.note")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var privacySection: some View {
        Section("settings.section.privacy") {
            Toggle("settings.privacy.locationSharing", isOn: $locationSharingEnabled)
            Text("settings.privacy.locationSharing.note")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var permissionsSection: some View {
        Section("settings.section.permissions") {
            SettingsPermissionRow(
                title: String(localized: "settings.permissions.location"),
                systemImage: "location",
                status: locationPermissionStatus
            )

            SettingsPermissionRow(
                title: String(localized: "settings.permissions.notifications"),
                systemImage: "bell",
                status: notificationPermissionStatus
            )

            Button {
                AppSettingsSystemOpener.open()
            } label: {
                Label("settings.permissions.openSystemSettings", systemImage: "gearshape")
            }

            Text("settings.permissions.note")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var securitySection: some View {
        Section("settings.section.security") {
            Toggle(isOn: biometricUnlockBinding) {
                Label("settings.security.biometricUnlock", systemImage: "lock.shield")
            }
            .disabled(!biometricAvailability.isAvailable)

            Text(biometricAvailability.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var productTierBinding: Binding<AppProductTier> {
        Binding(
            get: { appPreferences.productTier },
            set: { newValue in
                appPreferences.productTier = newValue
                normalizeDefaultSpaceType()
            }
        )
    }

    private var autoSyncBinding: Binding<Bool> {
        Binding(
            get: { appPreferences.autoSyncEnabled },
            set: { appPreferences.autoSyncEnabled = $0 }
        )
    }

    private var appLanguageBinding: Binding<AppLanguagePreference> {
        Binding(
            get: { appPreferences.appLanguage },
            set: { appPreferences.appLanguage = $0 }
        )
    }

    private var defaultCurrencyBinding: Binding<AppCurrencyPreference> {
        Binding(
            get: { appPreferences.defaultCurrency },
            set: { appPreferences.defaultCurrency = $0 }
        )
    }

    private var measurementSystemBinding: Binding<AppMeasurementSystemPreference> {
        Binding(
            get: { appPreferences.measurementSystem },
            set: { appPreferences.measurementSystem = $0 }
        )
    }

    private var weightUnitBinding: Binding<AppWeightUnitPreference> {
        Binding(
            get: { appPreferences.weightUnit },
            set: { appPreferences.weightUnit = $0 }
        )
    }

    private var weekStartBinding: Binding<AppWeekStartPreference> {
        Binding(
            get: { appPreferences.weekStart },
            set: { appPreferences.weekStart = $0 }
        )
    }

    private var noteFontDesignBinding: Binding<NoteEditorFontDesign> {
        Binding(
            get: { appPreferences.noteEditorFontDesign },
            set: { appPreferences.noteEditorFontDesign = $0 }
        )
    }

    private var noteFontSizeBinding: Binding<NoteEditorFontSizePreference> {
        Binding(
            get: { appPreferences.noteEditorFontSize },
            set: { appPreferences.noteEditorFontSize = $0 }
        )
    }

    private var biometricUnlockBinding: Binding<Bool> {
        Binding(
            get: { appPreferences.biometricUnlockEnabled && biometricAvailability.isAvailable },
            set: { appPreferences.biometricUnlockEnabled = $0 && biometricAvailability.isAvailable }
        )
    }

    private func refreshDerivedState() {
        normalizeDefaultSpaceType()
        biometricAvailability = SettingsBiometricAvailability.current()
        if !biometricAvailability.isAvailable {
            appPreferences.biometricUnlockEnabled = false
        }
        locationPermissionStatus = SettingsPermissionStatus(locationStatus: CLLocationManager().authorizationStatus)
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                notificationPermissionStatus = SettingsPermissionStatus(notificationStatus: settings.authorizationStatus)
            }
        }
    }

    private func normalizeDefaultSpaceType() {
        if !appPreferences.allowsSharedSpaces, defaultSpaceType == SpaceType.shared.rawValue {
            defaultSpaceType = SpaceType.personal.rawValue
        }
    }
}

private struct SettingsPermissionRow: View {
    let title: String
    let systemImage: String
    let status: SettingsPermissionStatus

    var body: some View {
        HStack(spacing: 12) {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(status.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(status.tint)
        }
    }
}

private enum SettingsPermissionStatus {
    case unknown
    case notDetermined
    case granted
    case denied
    case restricted

    init(locationStatus: CLAuthorizationStatus) {
        switch locationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            self = .granted
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        case .notDetermined:
            self = .notDetermined
        @unknown default:
            self = .unknown
        }
    }

    init(notificationStatus: UNAuthorizationStatus) {
        switch notificationStatus {
        case .authorized, .provisional:
            self = .granted
        #if os(iOS)
        case .ephemeral:
            self = .granted
        #endif
        case .denied:
            self = .denied
        case .notDetermined:
            self = .notDetermined
        @unknown default:
            self = .unknown
        }
    }

    var title: String {
        switch self {
        case .unknown: String(localized: "settings.permissions.status.unknown")
        case .notDetermined: String(localized: "settings.permissions.status.notDetermined")
        case .granted: String(localized: "settings.permissions.status.granted")
        case .denied: String(localized: "settings.permissions.status.denied")
        case .restricted: String(localized: "settings.permissions.status.restricted")
        }
    }

    var tint: Color {
        switch self {
        case .granted: .green
        case .denied, .restricted: .red
        case .notDetermined, .unknown: .secondary
        }
    }
}

private struct SettingsBiometricAvailability {
    let isAvailable: Bool
    let message: LocalizedStringKey

    static func current() -> SettingsBiometricAvailability {
        let context = LAContext()
        var error: NSError?
        let isAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

        guard isAvailable else {
            return SettingsBiometricAvailability(
                isAvailable: false,
                message: "settings.security.biometricUnavailable"
            )
        }

        switch context.biometryType {
        case .faceID:
            return SettingsBiometricAvailability(isAvailable: true, message: "settings.security.faceIDAvailable")
        case .touchID:
            return SettingsBiometricAvailability(isAvailable: true, message: "settings.security.touchIDAvailable")
        case .opticID:
            return SettingsBiometricAvailability(isAvailable: true, message: "settings.security.biometricAvailable")
        case .none:
            return SettingsBiometricAvailability(isAvailable: true, message: "settings.security.biometricAvailable")
        @unknown default:
            return SettingsBiometricAvailability(isAvailable: true, message: "settings.security.biometricAvailable")
        }
    }
}

private enum AppSettingsSystemOpener {
    static func open() {
        #if os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #elseif os(macOS)
        if let privacyURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(privacyURL)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
        #endif
    }
}

#endif
