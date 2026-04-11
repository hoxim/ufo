#if os(macOS)

import SwiftUI

struct MacSettingsScreen: View {
    var body: some View {
        NavigationStack {
            Form {
                AppSettingsCoreFormSections()

                Section("settings.section.devices") {
                    NavigationLink {
                        MacDeviceSessionsScreen()
                    } label: {
                        Label("settings.devices.manage", systemImage: "desktopcomputer.and.iphone")
                    }
                }
            }
            .navigationTitle("settings.title")
        }
    }
}

#Preview {
    MacSettingsScreen()
}

#endif
