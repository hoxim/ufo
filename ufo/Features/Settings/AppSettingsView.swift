import SwiftUI

struct AppSettingsView: View {
    @AppStorage("settings_space_limit") private var spaceLimit: Int = 5
    @AppStorage("settings_auto_sync_enabled") private var autoSyncEnabled: Bool = true
    @AppStorage("settings_default_space_type") private var defaultSpaceType: String = SpaceType.personal.rawValue
    @AppStorage("settings_location_sharing_enabled") private var locationSharingEnabled: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("settings.section.general") {
                    Stepper("\(String(localized: "settings.general.spaceLimit")): \(spaceLimit)", value: $spaceLimit, in: 1...30)
                    Toggle("settings.general.autoSync", isOn: $autoSyncEnabled)
                }

                Section("settings.section.defaultSpace") {
                    Picker("settings.defaultSpace.type", selection: $defaultSpaceType) {
                        Text("settings.defaultSpace.private").tag(SpaceType.personal.rawValue)
                        Text("settings.defaultSpace.shared").tag(SpaceType.shared.rawValue)
                    }
                }

                Section("settings.section.privacy") {
                    Toggle("settings.privacy.locationSharing", isOn: $locationSharingEnabled)
                    Text("settings.privacy.locationSharing.note")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("settings.title")
        }
    }
}

#Preview {
    AppSettingsView()
}
