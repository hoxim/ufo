import Foundation
import Auth
import Supabase

nonisolated private struct DeviceSessionUpsertParams: Encodable, Sendable {
    let target_session_id: UUID
    let target_platform: String
    let target_device_name: String
    let target_auth_method: String
    let target_approved_via: String?
    let target_metadata: [String: String]
}

nonisolated private struct DeviceSessionRevokeParams: Encodable, Sendable {
    let target_device_id: UUID
}

nonisolated private struct DeviceSessionRevokeOthersParams: Encodable, Sendable {
    let current_session_id: UUID
}

nonisolated private struct DeviceSessionApprovePairingParams: Encodable, Sendable {
    let input_code: String
    let input_access_token: String
    let input_refresh_token: String
    let input_user_email: String?
    let input_source_device_name: String
}

nonisolated private struct DeviceSessionApprovePairingBySecretParams: Encodable, Sendable {
    let input_request_id: UUID
    let input_request_secret: String
    let input_access_token: String
    let input_refresh_token: String
    let input_user_email: String?
    let input_source_device_name: String
}

final class DeviceSessionRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func currentSessionInfo() async throws -> CurrentAuthSessionInfo {
        let session = try await client.auth.session

        guard !session.isExpired else {
            throw AuthError.notAuthenticated
        }

        guard let sessionID = Self.extractSessionID(fromAccessToken: session.accessToken) else {
            throw DeviceSessionRepositoryError.invalidSessionIdentifier
        }

        return CurrentAuthSessionInfo(
            sessionID: sessionID,
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            userEmail: session.user.email
        )
    }

    @discardableResult
    func registerCurrentSession(_ context: DeviceSessionContext) async throws -> UUID {
        let session = try await currentSessionInfo()

        let params = DeviceSessionUpsertParams(
            target_session_id: session.sessionID,
            target_platform: context.platform,
            target_device_name: context.deviceName,
            target_auth_method: context.authMethod,
            target_approved_via: context.approvedVia,
            target_metadata: [:]
        )

        let builder = try client
            .rpc("ufo_upsert_device_session", params: params)

        let result: UUID = try await builder
            .single()
            .execute()
            .value

        return result
    }

    func fetchManagedDevices() async throws -> [ManagedDeviceSession] {
        try await client
            .from("device_sessions")
            .select()
            .order("last_seen_at", ascending: false)
            .execute()
            .value
    }

    func revokeDevice(id: UUID) async throws {
        let builder = try client
            .rpc("ufo_revoke_device_session", params: DeviceSessionRevokeParams(target_device_id: id))

        let _: Bool = try await builder
            .single()
            .execute()
            .value
    }

    func revokeOtherDevices() async throws {
        let session = try await currentSessionInfo()
        let builder = try client
            .rpc("ufo_revoke_other_device_sessions", params: DeviceSessionRevokeOthersParams(current_session_id: session.sessionID))

        let _: Int = try await builder
            .single()
            .execute()
            .value
    }

    func revokeAllDevices() async throws {
        let builder = try client
            .rpc("ufo_revoke_all_device_sessions")

        let _: Int = try await builder
            .single()
            .execute()
            .value
    }

    func approvePairingCode(_ code: String, sourceDeviceName: String) async throws {
        let session = try await currentSessionInfo()
        let params = DeviceSessionApprovePairingParams(
            input_code: code.trimmingCharacters(in: .whitespacesAndNewlines),
            input_access_token: session.accessToken,
            input_refresh_token: session.refreshToken,
            input_user_email: session.userEmail,
            input_source_device_name: sourceDeviceName
        )

        let builder = try client
            .rpc("ufo_approve_pairing_request", params: params)

        let _: UUID = try await builder
            .single()
            .execute()
            .value
    }

    func approvePairingRequest(_ payload: DevicePairingQRCodePayload, sourceDeviceName: String) async throws {
        let session = try await currentSessionInfo()
        let params = DeviceSessionApprovePairingBySecretParams(
            input_request_id: payload.requestID,
            input_request_secret: payload.requestSecret,
            input_access_token: session.accessToken,
            input_refresh_token: session.refreshToken,
            input_user_email: session.userEmail,
            input_source_device_name: sourceDeviceName
        )

        let builder = try client
            .rpc("ufo_approve_pairing_request_by_secret", params: params)

        let _: UUID = try await builder
            .single()
            .execute()
            .value
    }

    func signOutOtherSessions() async throws {
        try await revokeOtherDevices()
        try await client.auth.signOut(scope: .others)
    }

    func signOutCurrentSession() async throws {
        try await client.auth.signOut(scope: .local)
    }

    func signOutAllSessions() async throws {
        try await revokeAllDevices()
        try await client.auth.signOut(scope: .global)
    }

    private static func extractSessionID(fromAccessToken accessToken: String) -> UUID? {
        let segments = accessToken.split(separator: ".")
        guard segments.count == 3 else { return nil }

        var payload = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let padding = payload.count % 4
        if padding != 0 {
            payload += String(repeating: "=", count: 4 - padding)
        }

        guard
            let data = Data(base64Encoded: payload),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let rawSessionID = object["session_id"] as? String
        else {
            return nil
        }

        return UUID(uuidString: rawSessionID)
    }
}

enum DeviceSessionRepositoryError: LocalizedError {
    case invalidSessionIdentifier

    var errorDescription: String? {
        switch self {
        case .invalidSessionIdentifier:
            return "Nie udało się odczytać identyfikatora bieżącej sesji."
        }
    }
}
