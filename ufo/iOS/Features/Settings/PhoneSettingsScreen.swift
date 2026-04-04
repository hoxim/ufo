#if os(iOS)

import SwiftUI

struct PhoneSettingsScreen: View {
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(PhoneWatchSessionBridge.self) private var watchSessionBridge
    @AppStorage("settings_space_limit") private var spaceLimit: Int = 5
    @AppStorage("settings_default_space_type") private var defaultSpaceType: String = SpaceType.personal.rawValue
    @AppStorage("settings_location_sharing_enabled") private var locationSharingEnabled: Bool = false

    var body: some View {
        NavigationStack {
            Form {
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

                Section("settings.section.general") {
                    Stepper("\(String(localized: "settings.general.spaceLimit")): \(spaceLimit)", value: $spaceLimit, in: 1...30)
                    Toggle("settings.general.autoSync", isOn: autoSyncBinding)
                        .disabled(!appPreferences.supportsCloudFeatures)
                }

                Section("settings.section.defaultSpace") {
                    Picker("settings.defaultSpace.type", selection: $defaultSpaceType) {
                        Text("settings.defaultSpace.private").tag(SpaceType.personal.rawValue)
                        Text("settings.defaultSpace.shared").tag(SpaceType.shared.rawValue)
                    }
                    .disabled(!appPreferences.allowsSharedSpaces)
                }

                Section("settings.section.privacy") {
                    Toggle("settings.privacy.locationSharing", isOn: $locationSharingEnabled)
                    Text("settings.privacy.locationSharing.note")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("settings.section.devices") {
                    NavigationLink {
                        PhoneDeviceSessionsScreen()
                    } label: {
                        Label("settings.devices.manage", systemImage: "desktopcomputer.and.iphone")
                    }

                    if watchSessionBridge.supportsWatchPairing, watchSessionBridge.pendingApproval != nil {
                        Text("settings.devices.watch.pendingSettingsHint")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("settings.title")
            .onAppear {
                if !appPreferences.allowsSharedSpaces, defaultSpaceType == SpaceType.shared.rawValue {
                    defaultSpaceType = SpaceType.personal.rawValue
                }
            }
        }
    }

    private var productTierBinding: Binding<AppProductTier> {
        Binding(
            get: { appPreferences.productTier },
            set: { newValue in
                appPreferences.productTier = newValue
                if newValue == .standardOffline, defaultSpaceType == SpaceType.shared.rawValue {
                    defaultSpaceType = SpaceType.personal.rawValue
                }
            }
        )
    }

    private var autoSyncBinding: Binding<Bool> {
        Binding(
            get: { appPreferences.autoSyncEnabled },
            set: { appPreferences.autoSyncEnabled = $0 }
        )
    }
}

#Preview {
    PhoneSettingsScreen()
        .environment(PhoneWatchSessionBridge(authRepository: AuthMock.makeRepository(isLoggedIn: true)))
}

#endif
