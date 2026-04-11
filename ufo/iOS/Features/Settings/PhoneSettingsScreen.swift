#if os(iOS)

import SwiftUI

struct PhoneSettingsScreen: View {
    @Environment(PhoneWatchSessionBridge.self) private var watchSessionBridge

    var body: some View {
        NavigationStack {
            Form {
                AppSettingsCoreFormSections()

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
        }
    }
}

#Preview {
    PhoneSettingsScreen()
        .environment(PhoneWatchSessionBridge(authRepository: AuthMock.makeRepository(isLoggedIn: true)))
}

#endif
