#if os(watchOS)

import Foundation

struct DevicePairingQRCodePayload: Equatable, Sendable {
    static let scheme = "ufo"
    static let host = "pair-device"

    let requestID: UUID
    let requestSecret: String
    let shortCode: String
    let deviceName: String
    let platform: String
    let expiresAt: Date

    var qrString: String {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = Self.host
        components.queryItems = [
            URLQueryItem(name: "request_id", value: requestID.uuidString),
            URLQueryItem(name: "secret", value: requestSecret),
            URLQueryItem(name: "code", value: shortCode),
            URLQueryItem(name: "device_name", value: deviceName),
            URLQueryItem(name: "platform", value: platform),
            URLQueryItem(name: "expires_at", value: Self.iso8601Formatter.string(from: expiresAt))
        ]

        return components.string ?? ""
    }

    init(
        requestID: UUID,
        requestSecret: String,
        shortCode: String,
        deviceName: String,
        platform: String,
        expiresAt: Date
    ) {
        self.requestID = requestID
        self.requestSecret = requestSecret
        self.shortCode = shortCode
        self.deviceName = deviceName
        self.platform = platform
        self.expiresAt = expiresAt
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

#endif
