#if os(iOS)

import Foundation
import Observation
import UIKit
import WatchConnectivity

@MainActor
@Observable
final class PhoneWatchSessionBridge: NSObject, WCSessionDelegate {
    struct PendingApproval: Equatable {
        let request: WatchSessionTransferRequest
    }

    var pendingApproval: PendingApproval?
    var lastErrorMessage: String?
    var isWatchPaired = false
    var isWatchAppInstalled = false
    var isReachable = false

    private let authRepository: AuthRepository
    private let session: WCSession? = WCSession.isSupported() ? .default : nil
    private var activationState: WCSessionActivationState = .notActivated

    init(authRepository: AuthRepository) {
        self.authRepository = authRepository
        super.init()

        session?.delegate = self
        session?.activate()
        refreshState()
    }

    var supportsWatchPairing: Bool {
        session != nil
    }

    func approvePendingRequest() async {
        guard let pendingApproval, let session else {
            lastErrorMessage = WatchSessionTransferError.missingPendingRequest.localizedDescription
            return
        }

        do {
            let snapshot = try await authRepository.currentSessionSnapshot()
            let payload = WatchSessionTransferPayload(
                requestID: pendingApproval.request.requestID,
                accessToken: snapshot.accessToken,
                refreshToken: snapshot.refreshToken,
                userEmail: snapshot.userEmail,
                sourceDeviceName: UIDevice.current.name,
                issuedAt: Date()
            )

            try await sendMessage(payload.message, with: session)
            self.pendingApproval = nil
            self.lastErrorMessage = nil
        } catch let error as WatchSessionTransferError {
            lastErrorMessage = error.localizedDescription
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func rejectPendingRequest() async {
        guard let pendingApproval, let session else {
            lastErrorMessage = WatchSessionTransferError.missingPendingRequest.localizedDescription
            return
        }

        let message: [String: Any] = [
            WatchSessionTransferMessage.typeKey: WatchSessionTransferMessage.rejectSession,
            WatchSessionTransferMessage.requestIDKey: pendingApproval.request.requestID.uuidString,
            WatchSessionTransferMessage.errorMessageKey: WatchSessionTransferError.requestRejected.localizedDescription
        ]

        do {
            try await sendMessage(message, with: session)
        } catch {
            lastErrorMessage = error.localizedDescription
        }

        self.pendingApproval = nil
    }

    private func refreshState() {
        guard let session else { return }

        activationState = session.activationState
        isWatchPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
        isReachable = session.isReachable
    }

    private func handleRequestMessage(_ message: [String: Any]) {
        guard let request = WatchSessionTransferRequest(message: message) else {
            lastErrorMessage = WatchSessionTransferError.invalidPayload.localizedDescription
            return
        }

        guard authRepository.isLoggedIn else {
            lastErrorMessage = WatchSessionTransferError.phoneNotLoggedIn.localizedDescription
            if let session {
                let message: [String: Any] = [
                    WatchSessionTransferMessage.typeKey: WatchSessionTransferMessage.rejectSession,
                    WatchSessionTransferMessage.requestIDKey: request.requestID.uuidString,
                    WatchSessionTransferMessage.errorMessageKey: WatchSessionTransferError.phoneNotLoggedIn.localizedDescription
                ]
                session.sendMessage(message, replyHandler: nil, errorHandler: nil)
            }
            return
        }

        pendingApproval = PendingApproval(request: request)
        lastErrorMessage = nil
        refreshState()
    }

    private func sendMessage(_ message: [String: Any], with session: WCSession) async throws {
        try await waitForActivation(of: session)

        guard session.isReachable else {
            throw WatchSessionTransferError.phoneUnavailable
        }

        try await withCheckedThrowingContinuation { continuation in
            session.sendMessage(message) { _ in
                continuation.resume()
            } errorHandler: { error in
                continuation.resume(throwing: error)
            }
        }
    }

    private func waitForActivation(of session: WCSession) async throws {
        if session.activationState == .activated {
            activationState = .activated
            return
        }

        session.activate()

        for _ in 0..<20 {
            if session.activationState == .activated {
                activationState = .activated
                return
            }

            try await Task.sleep(for: .milliseconds(150))
        }

        throw WatchSessionTransferError.phoneUnavailable
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        Task { @MainActor in
            self.activationState = activationState
            self.refreshState()
            if let error {
                self.lastErrorMessage = error.localizedDescription
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            self.refreshState()
        }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            session.activate()
            self.refreshState()
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.refreshState()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.refreshState()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        guard
            let type = message["type"] as? String,
            type == "watch.requestSession"
        else {
            return
        }

        Task { @MainActor in
            self.handleRequestMessage(message)
        }
    }
}

#endif
