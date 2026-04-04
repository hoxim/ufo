#if os(iOS)

import SwiftUI

struct PadDeviceSessionsScreen: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(DeviceSessionStore.self) private var deviceSessionStore

    var body: some View {
        Form {
            pairingCodeSection
            devicesSection
            actionsSection
        }
        .navigationTitle("settings.devices.title")
        .task {
            await deviceSessionStore.refreshDevices()
        }
    }

    private var pairingCodeSection: some View {
        Section("settings.devices.section.pairCode") {
            TextField("settings.devices.field.code", text: pairingCodeBinding)
                .textInputAutocapitalization(.never)
                .keyboardType(.numberPad)

            Button("settings.devices.action.connect") {
                Task {
                    await deviceSessionStore.approvePairingCode(deviceName: CurrentDeviceContext.make().deviceName)
                }
            }
            .disabled(deviceSessionStore.pairingCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var devicesSection: some View {
        Section("settings.devices.section.loggedIn") {
            if deviceSessionStore.devices.isEmpty {
                Text("settings.devices.empty")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(deviceSessionStore.devices) { device in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(device.deviceName)
                                .font(.headline)
                            Spacer()
                            if device.sessionID == deviceSessionStore.currentSessionID {
                                Text("settings.devices.current")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text("\(device.platform) • \(device.authMethod)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(String(format: String(localized: "settings.devices.lastActivity"), device.lastSeenAt.formatted(date: .abbreviated, time: .shortened)))
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if let revokedAt = device.revokedAt {
                            Text(String(format: String(localized: "settings.devices.revoked"), revokedAt.formatted(date: .abbreviated, time: .shortened)))
                                .font(.footnote)
                                .foregroundStyle(.red)
                        } else if device.sessionID != deviceSessionStore.currentSessionID {
                            Button("settings.devices.action.revoke", role: .destructive) {
                                Task { await deviceSessionStore.revokeDevice(device) }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var actionsSection: some View {
        Section("settings.devices.section.sessions") {
            Button("settings.devices.action.refresh") {
                Task { await deviceSessionStore.refreshDevices() }
            }

            Button("settings.devices.action.signOutOthers", role: .destructive) {
                Task { await deviceSessionStore.signOutOtherDevices() }
            }

            Button("settings.devices.action.signOutAll", role: .destructive) {
                Task {
                    await deviceSessionStore.markAllDevicesRevoked()
                    await authStore.signOutEverywhere()
                }
            }

            if let errorMessage = deviceSessionStore.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var pairingCodeBinding: Binding<String> {
        Binding(
            get: { deviceSessionStore.pairingCodeInput },
            set: { deviceSessionStore.pairingCodeInput = $0 }
        )
    }
}

#Preview {
    let authRepository = AuthRepository(client: SupabaseConfig.client, isLoggedIn: true, currentUser: UserProfile(id: UUID(), email: "preview@ufo.app", fullName: "Preview User", role: "admin"))
    let spaceRepository = SpaceRepository(client: SupabaseConfig.client)
    let authStore = AuthStore(authRepository: authRepository, spaceRepository: spaceRepository)
    let deviceStore = DeviceSessionStore(repository: DeviceSessionRepository(client: SupabaseConfig.client), authRepository: authRepository)

    NavigationStack {
        PadDeviceSessionsScreen()
            .environment(authStore)
            .environment(deviceStore)
    }
}

#endif
