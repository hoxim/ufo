import Foundation
import Observation

@MainActor
@Observable
final class DeviceSessionStore {
    enum SyncState: Equatable {
        case idle
        case syncing
    }

    private let repository: DeviceSessionRepository
    private let authRepository: AuthRepository

    var devices: [ManagedDeviceSession] = []
    var currentSessionID: UUID?
    var currentDeviceID: UUID?
    var errorMessage: String?
    var state: SyncState = .idle
    var pairingCodeInput = ""

    init(repository: DeviceSessionRepository, authRepository: AuthRepository) {
        self.repository = repository
        self.authRepository = authRepository
    }

    var hasRegisteredCurrentDevice: Bool {
        currentDeviceID != nil
    }

    func bootstrap(context: DeviceSessionContext) async {
        guard authRepository.isLoggedIn else {
            reset()
            return
        }

        state = .syncing
        errorMessage = nil

        do {
            let session = try await repository.currentSessionInfo()
            currentSessionID = session.sessionID
            currentDeviceID = try await repository.registerCurrentSession(context)
            devices = try await repository.fetchManagedDevices()

            if let currentDevice = devices.first(where: { $0.sessionID == session.sessionID }) {
                currentDeviceID = currentDevice.id
                if currentDevice.revokedAt != nil {
                    try await repository.signOutCurrentSession()
                    authRepository.currentUser = nil
                    authRepository.isLoggedIn = false
                    reset()
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        state = .idle
    }

    func refreshDevices() async {
        guard authRepository.isLoggedIn else {
            reset()
            return
        }

        state = .syncing
        defer { state = .idle }

        do {
            let session = try await repository.currentSessionInfo()
            currentSessionID = session.sessionID
            devices = try await repository.fetchManagedDevices()
            currentDeviceID = devices.first(where: { $0.sessionID == session.sessionID })?.id
            errorMessage = nil

            if let currentDevice = devices.first(where: { $0.sessionID == session.sessionID }),
               currentDevice.revokedAt != nil {
                try await repository.signOutCurrentSession()
                authRepository.currentUser = nil
                authRepository.isLoggedIn = false
                reset()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func approvePairingCode(deviceName: String) async {
        let trimmedCode = pairingCodeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else { return }

        state = .syncing
        defer { state = .idle }

        do {
            try await repository.approvePairingCode(trimmedCode, sourceDeviceName: deviceName)
            pairingCodeInput = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func approvePairingQRCode(_ payload: DevicePairingQRCodePayload, deviceName: String) async {
        state = .syncing
        defer { state = .idle }

        do {
            try await repository.approvePairingRequest(payload, sourceDeviceName: deviceName)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func revokeDevice(_ device: ManagedDeviceSession) async {
        state = .syncing
        defer { state = .idle }

        do {
            try await repository.revokeDevice(id: device.id)
            devices = try await repository.fetchManagedDevices()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOutOtherDevices() async {
        state = .syncing
        defer { state = .idle }

        do {
            try await repository.signOutOtherSessions()
            devices = try await repository.fetchManagedDevices()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markAllDevicesRevoked() async {
        state = .syncing
        defer { state = .idle }

        do {
            try await repository.revokeAllDevices()
            devices = []
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reset() {
        devices = []
        currentSessionID = nil
        currentDeviceID = nil
        pairingCodeInput = ""
        errorMessage = nil
        state = .idle
    }
}
