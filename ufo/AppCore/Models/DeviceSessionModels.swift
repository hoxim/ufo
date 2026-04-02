import Foundation

struct DeviceSessionContext: Equatable, Sendable {
    let platform: String
    let deviceName: String
    let authMethod: String
    let approvedVia: String?
}

struct CurrentAuthSessionInfo: Equatable, Sendable {
    let sessionID: UUID
    let accessToken: String
    let refreshToken: String
    let userEmail: String?
}

struct ManagedDeviceSession: Identifiable, Decodable, Equatable, Sendable {
    let id: UUID
    let userID: UUID
    let sessionID: UUID
    let platform: String
    let deviceName: String
    let authMethod: String
    let approvedVia: String?
    let createdAt: Date
    let updatedAt: Date
    let lastSeenAt: Date
    let revokedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, platform
        case userID = "user_id"
        case sessionID = "session_id"
        case deviceName = "device_name"
        case authMethod = "auth_method"
        case approvedVia = "approved_via"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastSeenAt = "last_seen_at"
        case revokedAt = "revoked_at"
    }
}

struct DevicePairingRequest: Decodable, Equatable, Sendable {
    let requestID: UUID
    let shortCode: String
    let requestSecret: String
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case shortCode = "short_code"
        case requestSecret = "request_secret"
        case expiresAt = "expires_at"
    }
}

struct DevicePairingClaimResult: Decodable, Equatable, Sendable {
    let status: String
    let accessToken: String?
    let refreshToken: String?
    let userEmail: String?
    let sourceDeviceName: String?

    enum CodingKeys: String, CodingKey {
        case status
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case userEmail = "user_email"
        case sourceDeviceName = "source_device_name"
    }
}
