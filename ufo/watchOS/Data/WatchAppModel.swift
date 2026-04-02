#if os(watchOS)
import Foundation
import Observation
import Auth
import Supabase

@MainActor
@Observable
final class WatchAppModel {
    enum State: Equatable {
        case checkingSession
        case signedOut
        case loadingWorkspace
        case ready
    }

    private let lastSelectedSpaceIDKey = "watch_last_selected_space_id"
    private let service = WatchSupabaseService(client: WatchSupabaseConfig.client)
    private let sessionBridge = WatchSessionBridge()
    private var activePairingAttemptID: UUID?

    var state: State = .checkingSession
    var errorMessage: String?
    var currentUserEmail: String?
    var currentUserName: String?
    var spaces: [WatchSpaceSummary] = []
    var selectedSpaceID: UUID?
    var isAwaitingPhoneApproval = false
    var pairingCode: String?
    var pairingCodeExpiresAt: Date?
    var pairingQRCodePayload: DevicePairingQRCodePayload?
    var isAwaitingCodeApproval = false

    var selectedSpace: WatchSpaceSummary? {
        spaces.first(where: { $0.id == selectedSpaceID })
    }

    func bootstrap() async {
        state = .checkingSession
        errorMessage = nil

        do {
            let session = try await WatchSupabaseConfig.client.auth.session
            try await service.registerCurrentDevice(authMethod: "restored_session", approvedVia: nil)
            try await loadWorkspace(userId: session.user.id, fallbackEmail: session.user.email)
        } catch {
            spaces = []
            selectedSpaceID = nil
            currentUserEmail = nil
            currentUserName = nil
            isAwaitingPhoneApproval = false
            isAwaitingCodeApproval = false
            pairingCode = nil
            pairingCodeExpiresAt = nil
            pairingQRCodePayload = nil
            state = .signedOut
        }
    }

    func connectToPhone() async {
        errorMessage = nil
        isAwaitingPhoneApproval = true

        do {
            let payload = try await sessionBridge.requestSessionTransfer()
            let session = try await WatchSupabaseConfig.client.auth.setSession(
                accessToken: payload.accessToken,
                refreshToken: payload.refreshToken
            )
            try await service.registerCurrentDevice(authMethod: "session_transfer", approvedVia: "iphone")
            try await loadWorkspace(userId: session.user.id, fallbackEmail: payload.userEmail ?? session.user.email)
        } catch {
            state = .signedOut
            errorMessage = error.localizedDescription
        }

        isAwaitingPhoneApproval = false
    }

    func signIn(email: String, password: String) async {
        state = .checkingSession
        errorMessage = nil

        do {
            let session = try await WatchSupabaseConfig.client.auth.signIn(email: email, password: password)
            try await service.registerCurrentDevice(authMethod: "password", approvedVia: nil)
            try await loadWorkspace(userId: session.user.id, fallbackEmail: session.user.email)
        } catch {
            state = .signedOut
            errorMessage = "Nie udało się zalogować. Sprawdź dane konta."
        }
    }

    func startCodePairing() async {
        let pairingAttemptID = UUID()
        activePairingAttemptID = pairingAttemptID
        errorMessage = nil
        isAwaitingCodeApproval = true
        pairingCode = nil
        pairingCodeExpiresAt = nil
        pairingQRCodePayload = nil

        do {
            let request = try await service.createPairingRequest()
            guard activePairingAttemptID == pairingAttemptID else { return }
            pairingCode = request.shortCode
            pairingCodeExpiresAt = request.expiresAt
            pairingQRCodePayload = DevicePairingQRCodePayload(
                requestID: request.requestID,
                requestSecret: request.requestSecret,
                shortCode: request.shortCode,
                deviceName: request.deviceName,
                platform: request.platform,
                expiresAt: request.expiresAt
            )

            while Date() < request.expiresAt {
                guard activePairingAttemptID == pairingAttemptID, isAwaitingCodeApproval else {
                    return
                }

                let status = try await service.claimPairingRequest(
                    requestID: request.requestID,
                    requestSecret: request.requestSecret
                )

                switch status.status {
                case "approved":
                    guard let accessToken = status.accessToken, let refreshToken = status.refreshToken else {
                        throw WatchSessionTransferError.invalidPayload
                    }

                    let session = try await WatchSupabaseConfig.client.auth.setSession(
                        accessToken: accessToken,
                        refreshToken: refreshToken
                    )
                    try await service.registerCurrentDevice(authMethod: "pairing_code", approvedVia: "device_code")
                    activePairingAttemptID = nil
                    pairingCode = nil
                    pairingCodeExpiresAt = nil
                    pairingQRCodePayload = nil
                    isAwaitingCodeApproval = false
                    try await loadWorkspace(
                        userId: session.user.id,
                        fallbackEmail: status.userEmail ?? session.user.email
                    )
                    return

                case "expired":
                    throw WatchAppModelError.pairingCodeExpired

                case "canceled", "invalid":
                    throw WatchSessionTransferError.requestRejected

                default:
                    try await Task.sleep(for: .seconds(2))
                }
            }

            throw WatchAppModelError.pairingCodeExpired
        } catch {
            guard activePairingAttemptID == pairingAttemptID else { return }
            activePairingAttemptID = nil
            isAwaitingCodeApproval = false
            state = .signedOut
            pairingQRCodePayload = nil
            errorMessage = error.localizedDescription
        }
    }

    func cancelCodePairing() {
        activePairingAttemptID = nil
        isAwaitingCodeApproval = false
        pairingCode = nil
        pairingCodeExpiresAt = nil
        pairingQRCodePayload = nil
    }

    func signOut() async {
        do {
            try await WatchSupabaseConfig.client.auth.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }

        UserDefaults.standard.removeObject(forKey: lastSelectedSpaceIDKey)
        spaces = []
        selectedSpaceID = nil
        currentUserEmail = nil
        currentUserName = nil
        isAwaitingPhoneApproval = false
        activePairingAttemptID = nil
        isAwaitingCodeApproval = false
        pairingCode = nil
        pairingCodeExpiresAt = nil
        pairingQRCodePayload = nil
        state = .signedOut
    }

    func selectSpace(id: UUID) {
        selectedSpaceID = id
        UserDefaults.standard.set(id.uuidString, forKey: lastSelectedSpaceIDKey)
    }

    func fetchLists() async throws -> [WatchSharedListSummary] {
        guard let spaceID = selectedSpaceID else { return [] }
        return try await service.fetchLists(spaceId: spaceID)
    }

    func fetchListItems(listID: UUID) async throws -> [WatchSharedListItemSummary] {
        try await service.fetchListItems(listId: listID)
    }

    func fetchMissions() async throws -> [WatchMissionSummary] {
        guard let spaceID = selectedSpaceID else { return [] }
        return try await service.fetchMissions(spaceId: spaceID)
    }

    func fetchIncidents() async throws -> [WatchIncidentSummary] {
        guard let spaceID = selectedSpaceID else { return [] }
        return try await service.fetchIncidents(spaceId: spaceID)
    }

    private func loadWorkspace(userId: UUID, fallbackEmail: String?) async throws {
        state = .loadingWorkspace

        let workspace = try await service.fetchWorkspace(userId: userId, fallbackEmail: fallbackEmail)
        currentUserEmail = workspace.email
        currentUserName = workspace.displayName
        spaces = workspace.spaces

        if let storedID = storedSpaceID, spaces.contains(where: { $0.id == storedID }) {
            selectedSpaceID = storedID
        } else {
            selectedSpaceID = spaces.first?.id
        }

        state = .ready
        errorMessage = nil
    }

    private var storedSpaceID: UUID? {
        guard let rawValue = UserDefaults.standard.string(forKey: lastSelectedSpaceIDKey) else {
            return nil
        }
        return UUID(uuidString: rawValue)
    }
}

enum WatchAppModelError: LocalizedError {
    case pairingCodeExpired

    var errorDescription: String? {
        switch self {
        case .pairingCodeExpired:
            return "Kod połączenia wygasł. Wygeneruj nowy kod i spróbuj ponownie."
        }
    }
}

#endif
