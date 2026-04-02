#if os(watchOS)

import Foundation
import Observation
import WatchConnectivity
import WatchKit

@MainActor
@Observable
final class WatchSessionBridge: NSObject, WCSessionDelegate {
    private let session: WCSession? = WCSession.isSupported() ? .default : nil
    private var pendingContinuation: CheckedContinuation<WatchSessionTransferPayload, Error>?
    private var pendingRequestID: UUID?
    private var activationState: WCSessionActivationState = .notActivated

    var isPhoneReachable = false

    override init() {
        super.init()
        session?.delegate = self
        session?.activate()
        refreshState()
    }

    func requestSessionTransfer() async throws -> WatchSessionTransferPayload {
        guard let session else {
            throw WatchSessionTransferError.unsupported
        }

        try await waitForActivation(of: session)

        guard pendingContinuation == nil else {
            throw WatchSessionTransferError.phoneUnavailable
        }

        let request = WatchSessionTransferRequest(
            requestID: UUID(),
            watchName: WKInterfaceDevice.current().name,
            requestedAt: Date()
        )

        pendingRequestID = request.requestID

        return try await withCheckedThrowingContinuation { continuation in
            self.pendingContinuation = continuation

            session.sendMessage(request.message) { _ in
                // The actual session payload arrives in a follow-up message after phone approval.
            } errorHandler: { error in
                Task { @MainActor in
                    self.pendingContinuation?.resume(throwing: error)
                    self.clearPendingRequest()
                }
            }
        }
    }

    private func refreshState() {
        guard let session else { return }
        activationState = session.activationState
        isPhoneReachable = session.isReachable
    }

    private func clearPendingRequest() {
        pendingContinuation = nil
        pendingRequestID = nil
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

    private func handleIncomingMessage(_ message: [String: Any]) {
        guard let type = message[WatchSessionTransferMessage.typeKey] as? String else {
            return
        }

        switch type {
        case WatchSessionTransferMessage.approveSession:
            guard
                let payload = WatchSessionTransferPayload(message: message),
                payload.requestID == pendingRequestID
            else {
                pendingContinuation?.resume(throwing: WatchSessionTransferError.invalidPayload)
                clearPendingRequest()
                return
            }

            pendingContinuation?.resume(returning: payload)
            clearPendingRequest()

        case WatchSessionTransferMessage.rejectSession:
            pendingContinuation?.resume(throwing: WatchSessionTransferError.requestRejected)
            clearPendingRequest()

        default:
            break
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        Task { @MainActor in
            self.activationState = activationState
            self.refreshState()
            if let error, self.pendingContinuation != nil {
                self.pendingContinuation?.resume(throwing: error)
                self.clearPendingRequest()
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.refreshState()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            self.handleIncomingMessage(message)
        }
    }
}

#endif
