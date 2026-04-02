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

    init?(qrString: String) {
        guard
            let components = URLComponents(string: qrString),
            components.scheme == Self.scheme,
            components.host == Self.host
        else {
            return nil
        }

        let items = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) }
        )

        guard
            let rawRequestID = items["request_id"] ?? nil,
            let requestID = UUID(uuidString: rawRequestID),
            let requestSecret = items["secret"] ?? nil,
            let shortCode = items["code"] ?? nil,
            let deviceName = items["device_name"] ?? nil,
            let platform = items["platform"] ?? nil,
            let rawExpiresAt = items["expires_at"] ?? nil,
            let expiresAt = Self.iso8601Formatter.date(from: rawExpiresAt)
        else {
            return nil
        }

        self.init(
            requestID: requestID,
            requestSecret: requestSecret,
            shortCode: shortCode,
            deviceName: deviceName,
            platform: platform,
            expiresAt: expiresAt
        )
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
