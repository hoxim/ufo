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

    var selectedSpaceName: String {
        selectedSpace?.name ?? String(localized: "watch.feature.menu.spacePicker")
    }

    func bootstrap() async {
        WatchLog.msg("Watch bootstrap started")
        state = .checkingSession
        errorMessage = nil

        do {
            let session = try await WatchSupabaseConfig.client.auth.session
            WatchLog.msg("Watch bootstrap restored session for user=\(session.user.id.uuidString)")
            try await service.registerCurrentDevice(authMethod: "restored_session", approvedVia: nil)
            try await loadWorkspace(userId: session.user.id, fallbackEmail: session.user.email)
            WatchLog.msg("Watch bootstrap finished with ready state")
        } catch {
            WatchLog.error(error)
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
        WatchLog.msg("Watch connectToPhone started")
        errorMessage = nil
        isAwaitingPhoneApproval = true

        do {
            let payload = try await sessionBridge.requestSessionTransfer()
            WatchLog.msg("Watch connectToPhone received session payload from source=\(payload.sourceDeviceName)")
            let session = try await WatchSupabaseConfig.client.auth.setSession(
                accessToken: payload.accessToken,
                refreshToken: payload.refreshToken
            )
            try await service.registerCurrentDevice(authMethod: "session_transfer", approvedVia: "iphone")
            try await loadWorkspace(userId: session.user.id, fallbackEmail: payload.userEmail ?? session.user.email)
            WatchLog.msg("Watch connectToPhone completed successfully for user=\(session.user.id.uuidString)")
        } catch {
            WatchLog.error(error)
            state = .signedOut
            errorMessage = error.localizedDescription
        }

        isAwaitingPhoneApproval = false
    }

    func signIn(email: String, password: String) async {
        WatchLog.msg("Watch signIn started")
        state = .checkingSession
        errorMessage = nil

        do {
            let session = try await WatchSupabaseConfig.client.auth.signIn(email: email, password: password)
            try await service.registerCurrentDevice(authMethod: "password", approvedVia: nil)
            try await loadWorkspace(userId: session.user.id, fallbackEmail: session.user.email)
            WatchLog.msg("Watch signIn completed for user=\(session.user.id.uuidString)")
        } catch {
            WatchLog.error(error)
            state = .signedOut
            errorMessage = String(localized: "watch.auth.credentials.error")
        }
    }

    func startCodePairing() async {
        WatchLog.msg("Watch startCodePairing started")
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
            WatchLog.msg("Watch pairing request created id=\(request.requestID.uuidString)")
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
                WatchLog.msg("Watch pairing status requestID=\(request.requestID.uuidString) status=\(status.status)")

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
                    WatchLog.msg("Watch pairing completed successfully for user=\(session.user.id.uuidString)")
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
            WatchLog.error(error)
            activePairingAttemptID = nil
            isAwaitingCodeApproval = false
            state = .signedOut
            pairingQRCodePayload = nil
            errorMessage = error.localizedDescription
        }
    }

    func cancelCodePairing() {
        WatchLog.msg("Watch pairing canceled")
        activePairingAttemptID = nil
        isAwaitingCodeApproval = false
        pairingCode = nil
        pairingCodeExpiresAt = nil
        pairingQRCodePayload = nil
    }

    func signOut() async {
        WatchLog.msg("Watch signOut started")
        do {
            try await WatchSupabaseConfig.client.auth.signOut()
        } catch {
            WatchLog.error(error)
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

    func fetchNotes() async throws -> [WatchNoteSummary] {
        guard let spaceID = selectedSpaceID else { return [] }
        return try await service.fetchNotes(spaceId: spaceID)
    }

    func createNote(title: String, content: String) async throws -> WatchNoteSummary {
        guard let spaceID = selectedSpaceID else { throw WatchAppModelFlowError.missingSelectedSpace }
        return try await service.createNote(spaceId: spaceID, title: title, content: content)
    }

    func updateNote(_ note: WatchNoteSummary, title: String, content: String) async throws -> WatchNoteSummary {
        try await service.updateNote(note, title: title, content: content)
    }

    func deleteNote(_ note: WatchNoteSummary) async throws {
        try await service.deleteNote(note)
    }

    func fetchRoutines() async throws -> [WatchRoutineSummary] {
        guard let spaceID = selectedSpaceID else { return [] }
        return try await service.fetchRoutines(spaceId: spaceID)
    }

    func logRoutine(_ routine: WatchRoutineSummary, note: String?) async throws {
        guard let spaceID = selectedSpaceID else { throw WatchAppModelFlowError.missingSelectedSpace }
        try await service.logRoutine(routineID: routine.id, spaceID: spaceID, note: note)
    }

    func fetchSavedPlaces() async throws -> [WatchSavedPlaceSummary] {
        guard let spaceID = selectedSpaceID else { return [] }
        return try await service.fetchSavedPlaces(spaceId: spaceID)
    }

    func fetchPeople() async throws -> [WatchPersonSummary] {
        guard let spaceID = selectedSpaceID else { return [] }
        return try await service.fetchPeople(spaceId: spaceID)
    }

    func fetchBudgetSnapshot() async throws -> WatchBudgetSnapshot {
        guard let spaceID = selectedSpaceID else { throw WatchAppModelFlowError.missingSelectedSpace }
        return try await service.fetchBudgetSnapshot(spaceId: spaceID)
    }

    func fetchMission(id: UUID) async throws -> WatchMissionDetail {
        try await service.fetchMission(id: id)
    }

    func setMissionCompleted(_ mission: WatchMissionDetail, isCompleted: Bool) async throws {
        try await service.setMissionCompleted(id: mission.id, isCompleted: isCompleted, version: mission.version)
    }

    func fetchIncident(id: UUID) async throws -> WatchIncidentDetail {
        try await service.fetchIncident(id: id)
    }

    func updateIncidentStatus(_ incident: WatchIncidentDetail, status: String) async throws {
        try await service.updateIncidentStatus(id: incident.id, status: status, version: incident.version)
    }

    func addListItem(listID: UUID, title: String, position: Int) async throws {
        try await service.addListItem(listID: listID, title: title, position: position)
    }

    func toggleListItem(_ item: WatchSharedListItemSummary) async throws {
        try await service.toggleListItem(item)
    }

    func deleteListItem(_ item: WatchSharedListItemSummary) async throws {
        try await service.deleteListItem(item)
    }

    private func loadWorkspace(userId: UUID, fallbackEmail: String?) async throws {
        WatchLog.msg("Watch loadWorkspace started user=\(userId.uuidString)")
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
        WatchLog.msg("Watch loadWorkspace finished spaces=\(spaces.count) selectedSpace=\(selectedSpaceID?.uuidString ?? "nil")")
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
            return String(localized: "watch.auth.code.error.expired")
        }
    }
}

enum WatchAppModelFlowError: LocalizedError {
    case missingSelectedSpace

    var errorDescription: String? {
        switch self {
        case .missingSelectedSpace:
            return String(localized: "watch.common.error.selectSpace")
        }
    }
}

#endif
