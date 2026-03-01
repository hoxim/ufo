import SwiftUI

struct AppSettingsView: View {
    @AppStorage("settings_space_limit") private var spaceLimit: Int = 5
    @AppStorage("settings_auto_sync_enabled") private var autoSyncEnabled: Bool = true
    @AppStorage("settings_default_space_type") private var defaultSpaceType: String = SpaceType.personal.rawValue
    @AppStorage("settings_location_sharing_enabled") private var locationSharingEnabled: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    Stepper("Space limit: \(spaceLimit)", value: $spaceLimit, in: 1...30)
                    Toggle("Auto sync", isOn: $autoSyncEnabled)
                }

                Section("Default Space") {
                    Picker("Default type", selection: $defaultSpaceType) {
                        Text("Private").tag(SpaceType.personal.rawValue)
                        Text("Shared").tag(SpaceType.shared.rawValue)
                    }
                }

                Section("Privacy") {
                    Toggle("Location sharing", isOn: $locationSharingEnabled)
                    Text("To ustawienie określa domyślne zachowanie modułu mapy.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    AppSettingsView()
}
