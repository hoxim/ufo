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
        .navigationTitle("settings.devices.title")
        .sheet(isPresented: $isShowingQRScanner) {
            PhonePairingQRScannerSheet { payload in
                scannedQRCodePayload = payload
                isShowingQRScanner = false
            } onCancel: {
                isShowingQRScanner = false
            }
        }
        .confirmationDialog(
            "settings.devices.confirmConnectTitle",
            isPresented: scannedPayloadConfirmationBinding,
            titleVisibility: .visible
        ) {
            if let scannedQRCodePayload {
                Button(String(format: String(localized: "settings.devices.confirmConnectAction"), scannedQRCodePayload.deviceName)) {
                    Task {
                        await deviceSessionStore.approvePairingQRCode(
                            scannedQRCodePayload,
                            deviceName: CurrentDeviceContext.make().deviceName
                        )
                        self.scannedQRCodePayload = nil
                    }
                }
            }

            Button("settings.devices.confirmCancel", role: .cancel) {
                scannedQRCodePayload = nil
            }
        } message: {
            if let scannedQRCodePayload {
                Text(
                    String(
                        format: String(localized: "settings.devices.confirmMessage"),
                        scannedQRCodePayload.deviceName,
                        scannedQRCodePayload.shortCode
                    )
                )
            }
        }
        .task {
            await deviceSessionStore.refreshDevices()
        }
    }

    @ViewBuilder
    private var watchSection: some View {
        Section("settings.devices.section.watch") {
            if !watchSessionBridge.supportsWatchPairing {
                Text("settings.devices.watch.unsupported")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if !watchSessionBridge.isWatchPaired {
                Text("settings.devices.watch.notPaired")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if let pendingApproval = watchSessionBridge.pendingApproval {
                VStack(alignment: .leading, spacing: 6) {
                    Text("settings.devices.watch.pendingTitle")
                        .font(.headline)
                    Text(String(format: String(localized: "settings.devices.watch.pendingMessage"), pendingApproval.request.watchName))
                        .font(.footnote)
                    Text("settings.devices.watch.pendingHint")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button("settings.devices.watch.approve") {
                    Task { await watchSessionBridge.approvePendingRequest() }
                }
                .buttonStyle(.borderedProminent)

                Button("settings.devices.watch.reject", role: .destructive) {
                    Task { await watchSessionBridge.rejectPendingRequest() }
                }
            } else {
                Text("settings.devices.watch.idle")
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
        Section("settings.devices.section.pairCode") {
            Button {
                isShowingQRScanner = true
            } label: {
                Label("settings.devices.action.scanQR", systemImage: "qrcode.viewfinder")
            }

            TextField("settings.devices.field.code", text: pairingCodeBinding)
                .textInputAutocapitalization(.never)
                .keyboardType(.numberPad)

            Button("settings.devices.action.connect") {
                Task {
                    await deviceSessionStore.approvePairingCode(deviceName: CurrentDeviceContext.make().deviceName)
                }
            }
            .disabled(deviceSessionStore.pairingCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Text("settings.devices.pairingDescription")
                .font(.footnote)
                .foregroundStyle(.secondary)
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

            Text("settings.devices.footer")
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
