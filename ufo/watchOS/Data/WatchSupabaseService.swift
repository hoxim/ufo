#if os(watchOS)
import Foundation
import Supabase
import WatchKit

nonisolated private struct WatchDeviceSessionUpsertParams: Encodable, Sendable {
    let target_session_id: UUID
    let target_platform: String
    let target_device_name: String
    let target_auth_method: String
    let target_approved_via: String?
    let target_metadata: [String: String]
}

nonisolated private struct WatchCreatePairingRequestParams: Encodable, Sendable {
    let target_platform: String
    let target_device_name: String
}

nonisolated private struct WatchClaimPairingRequestParams: Encodable, Sendable {
    let input_request_id: UUID
    let input_request_secret: String
}

struct WatchSpaceSummary: Identifiable, Hashable {
    let id: UUID
    let name: String
    let role: String
}

struct WatchSharedListSummary: Identifiable, Hashable {
    let id: UUID
    let name: String
    let type: String
    let updatedAt: Date?
}

struct WatchSharedListItemSummary: Identifiable, Hashable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let position: Int
}

struct WatchMissionSummary: Identifiable, Hashable {
    let id: UUID
    let title: String
    let priority: String
    let isCompleted: Bool
    let dueDate: Date?
    let updatedAt: Date?
}

struct WatchIncidentSummary: Identifiable, Hashable {
    let id: UUID
    let title: String
    let severity: String
    let status: String
    let updatedAt: Date?
}

struct WatchWorkspaceContext {
    let userId: UUID
    let email: String?
    let displayName: String?
    let spaces: [WatchSpaceSummary]
}

struct WatchDevicePairingRequest {
    let requestID: UUID
    let shortCode: String
    let requestSecret: String
    let deviceName: String
    let platform: String
    let expiresAt: Date
}

struct WatchDevicePairingStatus {
    let status: String
    let accessToken: String?
    let refreshToken: String?
    let userEmail: String?
    let sourceDeviceName: String?
}

final class WatchSupabaseService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchWorkspace(userId: UUID, fallbackEmail: String?) async throws -> WatchWorkspaceContext {
        let profile: WatchProfileRecord = try await client
            .from("profiles")
            .select("id, email, full_name, space_members(user_id, role, joined_at, spaces(id, name, invite_code, category, version, updated_at))")
            .eq("id", value: userId)
            .single()
            .execute()
            .value

        let spaces = (profile.spaceMembers ?? []).compactMap { membership -> WatchSpaceSummary? in
            guard let space = membership.space else { return nil }
            return WatchSpaceSummary(
                id: space.id,
                name: space.name,
                role: membership.role
            )
        }

        return WatchWorkspaceContext(
            userId: userId,
            email: profile.email ?? fallbackEmail,
            displayName: profile.fullName,
            spaces: spaces
        )
    }

    func fetchLists(spaceId: UUID) async throws -> [WatchSharedListSummary] {
        let records: [WatchSharedListRecord] = try await client
            .from("shared_lists")
            .select("id, name, type, updated_at")
            .eq("space_id", value: spaceId)
            .is("deleted_at", value: nil)
            .order("updated_at", ascending: false)
            .execute()
            .value

        return records.map {
            WatchSharedListSummary(
                id: $0.id,
                name: $0.name,
                type: $0.type,
                updatedAt: $0.updatedAt
            )
        }
    }

    func fetchListItems(listId: UUID) async throws -> [WatchSharedListItemSummary] {
        let records: [WatchSharedListItemRecord] = try await client
            .from("shared_list_items")
            .select("id, title, is_completed, position")
            .eq("list_id", value: listId)
            .is("deleted_at", value: nil)
            .order("position", ascending: true)
            .execute()
            .value

        return records.map {
            WatchSharedListItemSummary(
                id: $0.id,
                title: $0.title,
                isCompleted: $0.isCompleted,
                position: $0.position
            )
        }
    }

    func fetchMissions(spaceId: UUID) async throws -> [WatchMissionSummary] {
        let records: [WatchMissionRecord] = try await client
            .from("missions")
            .select("id, title, priority, is_completed, due_date, last_updated_at")
            .eq("space_id", value: spaceId)
            .is("deleted_at", value: nil)
            .order("last_updated_at", ascending: false)
            .execute()
            .value

        return records.map {
            WatchMissionSummary(
                id: $0.id,
                title: $0.title,
                priority: $0.priority,
                isCompleted: $0.isCompleted,
                dueDate: $0.dueDate,
                updatedAt: $0.lastUpdatedAt
            )
        }
    }

    func fetchIncidents(spaceId: UUID) async throws -> [WatchIncidentSummary] {
        let records: [WatchIncidentRecord] = try await client
            .from("incidents")
            .select("id, title, severity, status, last_updated_at")
            .eq("space_id", value: spaceId)
            .is("deleted_at", value: nil)
            .order("last_updated_at", ascending: false)
            .execute()
            .value

        return records.map {
            WatchIncidentSummary(
                id: $0.id,
                title: $0.title,
                severity: $0.severity,
                status: $0.status,
                updatedAt: $0.lastUpdatedAt
            )
        }
    }

    func registerCurrentDevice(authMethod: String, approvedVia: String?) async throws {
        let session = try await client.auth.session
        guard let sessionID = Self.extractSessionID(fromAccessToken: session.accessToken) else {
            throw WatchSupabaseServiceError.invalidSessionIdentifier
        }

        let builder = try client
            .rpc(
                "ufo_upsert_device_session",
                params: WatchDeviceSessionUpsertParams(
                    target_session_id: sessionID,
                    target_platform: "watchOS",
                    target_device_name: WatchKit.WKInterfaceDevice.current().name,
                    target_auth_method: authMethod,
                    target_approved_via: approvedVia,
                    target_metadata: [:]
                )
            )

        let _: UUID = try await builder
            .single()
            .execute()
            .value
    }

    func createPairingRequest() async throws -> WatchDevicePairingRequest {
        let builder = try client
            .rpc(
                "ufo_create_pairing_request",
                params: WatchCreatePairingRequestParams(
                    target_platform: "watchOS",
                    target_device_name: WatchKit.WKInterfaceDevice.current().name
                )
            )

        let result: WatchPairingRequestRecord = try await builder
            .single()
            .execute()
            .value

        return WatchDevicePairingRequest(
            requestID: result.requestID,
            shortCode: result.shortCode,
            requestSecret: result.requestSecret,
            deviceName: WatchKit.WKInterfaceDevice.current().name,
            platform: "watchOS",
            expiresAt: result.expiresAt
        )
    }

    func claimPairingRequest(requestID: UUID, requestSecret: String) async throws -> WatchDevicePairingStatus {
        let builder = try client
            .rpc(
                "ufo_claim_pairing_request",
                params: WatchClaimPairingRequestParams(
                    input_request_id: requestID,
                    input_request_secret: requestSecret
                )
            )

        let result: WatchPairingClaimRecord = try await builder
            .single()
            .execute()
            .value

        return WatchDevicePairingStatus(
            status: result.status,
            accessToken: result.accessToken,
            refreshToken: result.refreshToken,
            userEmail: result.userEmail,
            sourceDeviceName: result.sourceDeviceName
        )
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

private struct WatchProfileRecord: Decodable {
    let id: UUID
    let email: String?
    let fullName: String?
    let spaceMembers: [WatchSpaceMembershipRecord]?

    enum CodingKeys: String, CodingKey {
        case id, email
        case fullName = "full_name"
        case spaceMembers = "space_members"
    }
}

private struct WatchSpaceMembershipRecord: Decodable {
    let userId: UUID
    let role: String
    let joinedAt: Date?
    let space: WatchSpaceRecord?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case role
        case joinedAt = "joined_at"
        case space = "spaces"
    }
}

private struct WatchSpaceRecord: Decodable {
    let id: UUID
    let name: String
    let inviteCode: String?
    let category: String?
    let version: Int?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, category, version
        case inviteCode = "invite_code"
        case updatedAt = "updated_at"
    }
}

private struct WatchSharedListRecord: Decodable {
    let id: UUID
    let name: String
    let type: String
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, type
        case updatedAt = "updated_at"
    }
}

private struct WatchSharedListItemRecord: Decodable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let position: Int

    enum CodingKeys: String, CodingKey {
        case id, title, position
        case isCompleted = "is_completed"
    }
}

private struct WatchMissionRecord: Decodable {
    let id: UUID
    let title: String
    let priority: String
    let isCompleted: Bool
    let dueDate: Date?
    let lastUpdatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, priority
        case isCompleted = "is_completed"
        case dueDate = "due_date"
        case lastUpdatedAt = "last_updated_at"
    }
}

private struct WatchIncidentRecord: Decodable {
    let id: UUID
    let title: String
    let severity: String
    let status: String
    let lastUpdatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, severity, status
        case lastUpdatedAt = "last_updated_at"
    }
}

private struct WatchPairingRequestRecord: Decodable {
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

private struct WatchPairingClaimRecord: Decodable {
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

enum WatchSupabaseServiceError: LocalizedError {
    case invalidSessionIdentifier

    var errorDescription: String? {
        switch self {
        case .invalidSessionIdentifier:
            return "Nie udało się odczytać identyfikatora sesji zegarka."
        }
    }
}

#endif
