#if os(macOS)

import SwiftUI

struct MacDeviceSessionsScreen: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(DeviceSessionStore.self) private var deviceSessionStore

    var body: some View {
        Form {
            pairingCodeSection
            devicesSection
            actionsSection
        }
        .navigationTitle("Urządzenia")
        .task {
            await deviceSessionStore.refreshDevices()
        }
    }

    private var pairingCodeSection: some View {
        Section("Połącz urządzenie kodem") {
            TextField("Kod z zegarka lub innego urządzenia", text: pairingCodeBinding)

            Button("Połącz urządzenie") {
                Task {
                    await deviceSessionStore.approvePairingCode(deviceName: CurrentDeviceContext.make().deviceName)
                }
            }
            .disabled(deviceSessionStore.pairingCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var devicesSection: some View {
        Section("Zalogowane urządzenia") {
            if deviceSessionStore.devices.isEmpty {
                Text("Brak aktywnych urządzeń do pokazania.")
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
                                Text("To urządzenie")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text("\(device.platform) • \(device.authMethod)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("Ostatnia aktywność: \(device.lastSeenAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if let revokedAt = device.revokedAt {
                            Text("Zablokowane: \(revokedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        } else if device.sessionID != deviceSessionStore.currentSessionID {
                            Button("Wyloguj to urządzenie", role: .destructive) {
                                Task { await deviceSessionStore.revokeDevice(device) }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var actionsSection: some View {
        Section("Sesje") {
            Button("Odśwież listę") {
                Task { await deviceSessionStore.refreshDevices() }
            }

            Button("Wyloguj z innych urządzeń", role: .destructive) {
                Task { await deviceSessionStore.signOutOtherDevices() }
            }

            Button("Wyloguj wszędzie", role: .destructive) {
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
        MacDeviceSessionsScreen()
            .environment(authStore)
            .environment(deviceStore)
    }
}

#endif
