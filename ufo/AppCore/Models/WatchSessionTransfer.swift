import Foundation

struct WatchSessionTransferRequest: Codable, Equatable, Sendable {
    let requestID: UUID
    let watchName: String
    let requestedAt: Date
}

struct WatchSessionTransferPayload: Codable, Equatable, Sendable {
    let requestID: UUID
    let accessToken: String
    let refreshToken: String
    let userEmail: String?
    let sourceDeviceName: String
    let issuedAt: Date
}

struct AuthSessionSnapshot: Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let userEmail: String?
}

enum WatchSessionTransferError: LocalizedError, Equatable {
    case unsupported
    case companionAppNotInstalled
    case phoneUnavailable
    case phoneNotLoggedIn
    case requestRejected
    case missingPendingRequest
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return String(localized: "watch.session.error.unsupported")
        case .companionAppNotInstalled:
            return String(localized: "watch.session.error.companionAppNotInstalled")
        case .phoneUnavailable:
            return String(localized: "watch.session.error.phoneUnavailable")
        case .phoneNotLoggedIn:
            return String(localized: "watch.session.error.phoneNotLoggedIn")
        case .requestRejected:
            return String(localized: "watch.session.error.requestRejected")
        case .missingPendingRequest:
            return String(localized: "watch.session.error.missingPendingRequest")
        case .invalidPayload:
            return String(localized: "watch.session.error.invalidPayload")
        }
    }
}

enum WatchSessionTransferMessage {
    static let typeKey = "type"
    static let requestIDKey = "requestID"
    static let watchNameKey = "watchName"
    static let requestedAtKey = "requestedAt"
    static let accessTokenKey = "accessToken"
    static let refreshTokenKey = "refreshToken"
    static let userEmailKey = "userEmail"
    static let sourceDeviceNameKey = "sourceDeviceName"
    static let issuedAtKey = "issuedAt"
    static let errorMessageKey = "errorMessage"

    static let requestSession = "watch.requestSession"
    static let approveSession = "watch.approveSession"
    static let rejectSession = "watch.rejectSession"
}

extension WatchSessionTransferRequest {
    var message: [String: Any] {
        [
            WatchSessionTransferMessage.typeKey: WatchSessionTransferMessage.requestSession,
            WatchSessionTransferMessage.requestIDKey: requestID.uuidString,
            WatchSessionTransferMessage.watchNameKey: watchName,
            WatchSessionTransferMessage.requestedAtKey: requestedAt.timeIntervalSince1970
        ]
    }

    init?(message: [String: Any]) {
        guard
            let rawRequestID = message[WatchSessionTransferMessage.requestIDKey] as? String,
            let requestID = UUID(uuidString: rawRequestID),
            let watchName = message[WatchSessionTransferMessage.watchNameKey] as? String,
            let requestedAtInterval = message[WatchSessionTransferMessage.requestedAtKey] as? TimeInterval
        else {
            return nil
        }

        self.init(
            requestID: requestID,
            watchName: watchName,
            requestedAt: Date(timeIntervalSince1970: requestedAtInterval)
        )
    }
}

extension WatchSessionTransferPayload {
    var message: [String: Any] {
        [
            WatchSessionTransferMessage.typeKey: WatchSessionTransferMessage.approveSession,
            WatchSessionTransferMessage.requestIDKey: requestID.uuidString,
            WatchSessionTransferMessage.accessTokenKey: accessToken,
            WatchSessionTransferMessage.refreshTokenKey: refreshToken,
            WatchSessionTransferMessage.userEmailKey: userEmail ?? "",
            WatchSessionTransferMessage.sourceDeviceNameKey: sourceDeviceName,
            WatchSessionTransferMessage.issuedAtKey: issuedAt.timeIntervalSince1970
        ]
    }

    init?(message: [String: Any]) {
        guard
            let rawRequestID = message[WatchSessionTransferMessage.requestIDKey] as? String,
            let requestID = UUID(uuidString: rawRequestID),
            let accessToken = message[WatchSessionTransferMessage.accessTokenKey] as? String,
            let refreshToken = message[WatchSessionTransferMessage.refreshTokenKey] as? String,
            let sourceDeviceName = message[WatchSessionTransferMessage.sourceDeviceNameKey] as? String,
            let issuedAtInterval = message[WatchSessionTransferMessage.issuedAtKey] as? TimeInterval
        else {
            return nil
        }

        let userEmailValue = message[WatchSessionTransferMessage.userEmailKey] as? String

        self.init(
            requestID: requestID,
            accessToken: accessToken,
            refreshToken: refreshToken,
            userEmail: userEmailValue?.isEmpty == true ? nil : userEmailValue,
            sourceDeviceName: sourceDeviceName,
            issuedAt: Date(timeIntervalSince1970: issuedAtInterval)
        )
    }
}
