#if os(iOS)

import SwiftUI

struct PadSettingsScreen: View {
    var body: some View {
        NavigationStack {
            Form {
                AppSettingsCoreFormSections()

                Section("settings.section.devices") {
                    NavigationLink {
                        PadDeviceSessionsScreen()
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
    PadSettingsScreen()
}

#endif
