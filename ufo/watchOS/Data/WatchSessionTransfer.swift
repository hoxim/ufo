#if os(watchOS)

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

enum WatchSessionTransferError: LocalizedError, Equatable {
    case unsupported
    case phoneUnavailable
    case requestRejected
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "To urządzenie nie obsługuje parowania sesji z Apple Watch."
        case .phoneUnavailable:
            return "Nie udało się połączyć z iPhonem. Otwórz UFO na telefonie i spróbuj ponownie."
        case .requestRejected:
            return "Prośba o połączenie została odrzucona na iPhonie."
        case .invalidPayload:
            return "Nie udało się odczytać danych sesji z iPhone'a."
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
}

extension WatchSessionTransferPayload {
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

#endif
