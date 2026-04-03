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
    var isCompanionAppInstalled = false

    override init() {
        super.init()
        session?.delegate = self
        session?.activate()
        refreshState()
        WatchLog.msg("WatchSessionBridge initialized supported=\(session != nil)")
    }

    func requestSessionTransfer() async throws -> WatchSessionTransferPayload {
        WatchLog.msg("WatchSessionBridge requestSessionTransfer started")
        guard let session else {
            WatchLog.error("WatchSessionBridge unsupported on this device")
            throw WatchSessionTransferError.unsupported
        }

        try await waitForActivation(of: session)
        refreshState()

        guard session.isCompanionAppInstalled else {
            WatchLog.error("WatchSessionBridge companion app missing reachable=\(session.isReachable)")
            throw WatchSessionTransferError.companionAppNotInstalled
        }

        guard session.isReachable else {
            WatchLog.error("WatchSessionBridge phone unreachable companionInstalled=\(session.isCompanionAppInstalled)")
            throw WatchSessionTransferError.phoneUnavailable
        }

        guard pendingContinuation == nil else {
            WatchLog.error("WatchSessionBridge already has pending continuation")
            throw WatchSessionTransferError.phoneUnavailable
        }

        let request = WatchSessionTransferRequest(
            requestID: UUID(),
            watchName: WKInterfaceDevice.current().name,
            requestedAt: Date()
        )

        pendingRequestID = request.requestID
        WatchLog.msg("WatchSessionBridge sending request id=\(request.requestID.uuidString) watch=\(request.watchName)")

        return try await withCheckedThrowingContinuation { continuation in
            self.pendingContinuation = continuation

            session.sendMessage(request.message) { _ in
                // The actual session payload arrives in a follow-up message after phone approval.
            } errorHandler: { error in
                Task { @MainActor in
                    WatchLog.error(error)
                    self.pendingContinuation?.resume(throwing: self.mapTransferError(error))
                    self.clearPendingRequest()
                }
            }
        }
    }

    private func refreshState() {
        guard let session else { return }
        activationState = session.activationState
        isPhoneReachable = session.isReachable
        isCompanionAppInstalled = session.isCompanionAppInstalled
        WatchLog.msg(
            "WatchSessionBridge state activation=\(String(describing: activationState.rawValue)) companionInstalled=\(session.isCompanionAppInstalled) reachable=\(session.isReachable)"
        )
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
                WatchLog.msg("WatchSessionBridge activation completed")
                return
            }

            try await Task.sleep(for: .milliseconds(150))
        }

        WatchLog.error("WatchSessionBridge activation timed out")
        throw WatchSessionTransferError.phoneUnavailable
    }

    private func handleIncomingMessage(_ message: [String: Any]) {
        guard let type = message[WatchSessionTransferMessage.typeKey] as? String else {
            return
        }

        WatchLog.msg("WatchSessionBridge received message type=\(type)")

        switch type {
        case WatchSessionTransferMessage.approveSession:
            guard
                let payload = WatchSessionTransferPayload(message: message),
                payload.requestID == pendingRequestID
            else {
                WatchLog.error("WatchSessionBridge received invalid approval payload")
                pendingContinuation?.resume(throwing: WatchSessionTransferError.invalidPayload)
                clearPendingRequest()
                return
            }

            pendingContinuation?.resume(returning: payload)
            clearPendingRequest()

        case WatchSessionTransferMessage.rejectSession:
            let explicitMessage = (message[WatchSessionTransferMessage.errorMessageKey] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let explicitMessage, !explicitMessage.isEmpty {
                pendingContinuation?.resume(throwing: WatchSessionTransferRemoteError(message: explicitMessage))
            } else {
                pendingContinuation?.resume(throwing: WatchSessionTransferError.requestRejected)
            }
            clearPendingRequest()

        default:
            break
        }
    }

    private func mapTransferError(_ error: Error) -> Error {
        let nsError = error as NSError
        guard nsError.domain == WCErrorDomain, let code = WCError.Code(rawValue: nsError.code) else {
            return error
        }

        switch code {
        case .companionAppNotInstalled:
            return WatchSessionTransferError.companionAppNotInstalled
        case .notReachable, .deliveryFailed, .transferTimedOut:
            return WatchSessionTransferError.phoneUnavailable
        default:
            return error
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
                WatchLog.error(error)
                self.pendingContinuation?.resume(throwing: self.mapTransferError(error))
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

private struct WatchSessionTransferRemoteError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

#endif
