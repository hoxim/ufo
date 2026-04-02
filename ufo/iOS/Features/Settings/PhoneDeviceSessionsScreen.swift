#if os(iOS)

import SwiftUI

struct PhoneDeviceSessionsScreen: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(DeviceSessionStore.self) private var deviceSessionStore
    @Environment(PhoneWatchSessionBridge.self) private var watchSessionBridge

    @State private var isShowingQRScanner = false
    @State private var scannedQRCodePayload: DevicePairingQRCodePayload?

    var body: some View {
        Form {
            watchSection
            pairingCodeSection
            devicesSection
            actionsSection
        }
        .navigationTitle("Urządzenia")
        .sheet(isPresented: $isShowingQRScanner) {
            PhonePairingQRScannerSheet { payload in
                scannedQRCodePayload = payload
                isShowingQRScanner = false
            } onCancel: {
                isShowingQRScanner = false
            }
        }
        .confirmationDialog(
            "Połączyć urządzenie?",
            isPresented: scannedPayloadConfirmationBinding,
            titleVisibility: .visible
        ) {
            if let scannedQRCodePayload {
                Button("Połącz \(scannedQRCodePayload.deviceName)") {
                    Task {
                        await deviceSessionStore.approvePairingQRCode(
                            scannedQRCodePayload,
                            deviceName: CurrentDeviceContext.make().deviceName
                        )
                        self.scannedQRCodePayload = nil
                    }
                }
            }

            Button("Anuluj", role: .cancel) {
                scannedQRCodePayload = nil
            }
        } message: {
            if let scannedQRCodePayload {
                Text("Urządzenie: \(scannedQRCodePayload.deviceName)\nKod: \(scannedQRCodePayload.shortCode)")
            }
        }
        .task {
            await deviceSessionStore.refreshDevices()
        }
    }

    @ViewBuilder
    private var watchSection: some View {
        Section("Apple Watch") {
            if !watchSessionBridge.supportsWatchPairing {
                Text("To urządzenie nie obsługuje parowania z Apple Watch.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if !watchSessionBridge.isWatchPaired {
                Text("Sparuj Apple Watch z tym iPhonem, aby przekazywać sesję bez wpisywania hasła na zegarku.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if let pendingApproval = watchSessionBridge.pendingApproval {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Oczekująca prośba")
                        .font(.headline)
                    Text("Zegarek „\(pendingApproval.request.watchName)” prosi o dostęp do Twojej aktywnej sesji.")
                        .font(.footnote)
                    Text("Zatwierdź tylko, jeśli to Twój zegarek i masz otwarte UFO na jego ekranie logowania.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button("Zatwierdź połączenie") {
                    Task { await watchSessionBridge.approvePendingRequest() }
                }
                .buttonStyle(.borderedProminent)

                Button("Odrzuć", role: .destructive) {
                    Task { await watchSessionBridge.rejectPendingRequest() }
                }
            } else {
                Text("Na zegarku wybierz „Połącz z iPhonem”, a tutaj pojawi się prośba do zatwierdzenia.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let lastErrorMessage = watchSessionBridge.lastErrorMessage {
                Text(lastErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var pairingCodeSection: some View {
        Section("Połącz urządzenie kodem") {
            Button {
                isShowingQRScanner = true
            } label: {
                Label("Zeskanuj QR z zegarka", systemImage: "qrcode.viewfinder")
            }

            TextField("Kod z zegarka lub innego urządzenia", text: pairingCodeBinding)
                .textInputAutocapitalization(.never)
                .keyboardType(.numberPad)

            Button("Połącz urządzenie") {
                Task {
                    await deviceSessionStore.approvePairingCode(deviceName: CurrentDeviceContext.make().deviceName)
                }
            }
            .disabled(deviceSessionStore.pairingCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Text("Użyj tego, gdy chcesz zalogować Apple Watch albo inne ograniczone urządzenie bez pełnego formularza logowania.")
                .font(.footnote)
                .foregroundStyle(.secondary)
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
                                Task {
                                    await deviceSessionStore.revokeDevice(device)
                                }
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

            Text("Wylogowanie konkretnego urządzenia odetnie je przy najbliższym odświeżeniu sesji w aplikacji. Wylogowanie z innych urządzeń używa także mechanizmu sesji Supabase.")
                .font(.footnote)
                .foregroundStyle(.secondary)

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

    private var scannedPayloadConfirmationBinding: Binding<Bool> {
        Binding(
            get: { scannedQRCodePayload != nil },
            set: { isPresented in
                if !isPresented {
                    scannedQRCodePayload = nil
                }
            }
        )
    }
}

#Preview {
    let authRepository = AuthRepository(client: SupabaseConfig.client, isLoggedIn: true, currentUser: UserProfile(id: UUID(), email: "preview@ufo.app", fullName: "Preview User", role: "admin"))
    let spaceRepository = SpaceRepository(client: SupabaseConfig.client)
    let authStore = AuthStore(authRepository: authRepository, spaceRepository: spaceRepository)
    let deviceStore = DeviceSessionStore(repository: DeviceSessionRepository(client: SupabaseConfig.client), authRepository: authRepository)

    NavigationStack {
        PhoneDeviceSessionsScreen()
            .environment(authStore)
            .environment(deviceStore)
            .environment(PhoneWatchSessionBridge(authRepository: authRepository))
    }
}

#endif
