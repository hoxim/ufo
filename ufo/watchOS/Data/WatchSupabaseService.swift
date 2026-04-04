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
    let version: Int
}

struct WatchMissionSummary: Identifiable, Hashable {
    let id: UUID
    let title: String
    let priority: String
    let isCompleted: Bool
    let dueDate: Date?
    let updatedAt: Date?
}

struct WatchMissionDetail: Identifiable, Hashable {
    let id: UUID
    let title: String
    let description: String
    let priority: String
    let isCompleted: Bool
    let difficulty: Int
    let dueDate: Date?
    let savedPlaceName: String?
    let updatedAt: Date?
    let version: Int
}

struct WatchIncidentSummary: Identifiable, Hashable {
    let id: UUID
    let title: String
    let severity: String
    let status: String
    let updatedAt: Date?
}

struct WatchIncidentDetail: Identifiable, Hashable {
    let id: UUID
    let title: String
    let description: String?
    let severity: String
    let status: String
    let occurrenceDate: Date
    let updatedAt: Date?
    let version: Int
}

struct WatchNoteSummary: Identifiable, Hashable {
    let id: UUID
    let title: String
    let content: String
    let isPinned: Bool
    let updatedAt: Date?
    let version: Int
}

struct WatchRoutineSummary: Identifiable, Hashable {
    let id: UUID
    let title: String
    let category: String
    let personName: String?
    let notes: String?
    let startMinuteOfDay: Int
    let durationMinutes: Int
    let activeWeekdaysRaw: String
    let updatedAt: Date?

    var activeWeekdays: [Int] {
        activeWeekdaysRaw
            .split(separator: ",")
            .compactMap { Int($0) }
            .filter { (1...7).contains($0) }
    }
}

struct WatchSavedPlaceSummary: Identifiable, Hashable {
    let id: UUID
    let name: String
    let description: String?
    let category: String?
    let address: String?
    let latitude: Double
    let longitude: Double
    let radiusMeters: Double
}

struct WatchPersonSummary: Identifiable, Hashable {
    let id: UUID
    let displayName: String
    let email: String
    let role: String
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
        WatchLog.msg("WatchSupabaseService.fetchWorkspace user=\(userId.uuidString)")
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
            .select("id, title, is_completed, position, version")
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
                position: $0.position,
                version: $0.version
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

    func fetchNotes(spaceId: UUID) async throws -> [WatchNoteSummary] {
        let records: [WatchNoteRecord] = try await client
            .from("notes")
            .select("id, title, content, is_pinned, updated_at, version")
            .eq("space_id", value: spaceId)
            .is("deleted_at", value: nil)
            .order("is_pinned", ascending: false)
            .order("updated_at", ascending: false)
            .execute()
            .value

        return records.map {
            WatchNoteSummary(
                id: $0.id,
                title: $0.title,
                content: $0.content,
                isPinned: $0.isPinned,
                updatedAt: $0.updatedAt,
                version: $0.version
            )
        }
    }

    func createNote(spaceId: UUID, title: String, content: String) async throws -> WatchNoteSummary {
        let actorID = try await currentUserID()
        let now = Date()
        let noteID = UUID()

        let record: WatchNoteRecord = try await client
            .from("notes")
            .insert(
                WatchNoteInsertPayload(
                    id: noteID,
                    space_id: spaceId,
                    title: title,
                    content: content,
                    created_by: actorID,
                    updated_by: actorID,
                    updated_at: now,
                    version: 1
                )
            )
            .select("id, title, content, is_pinned, updated_at, version")
            .single()
            .execute()
            .value

        return WatchNoteSummary(
            id: record.id,
            title: record.title,
            content: record.content,
            isPinned: record.isPinned,
            updatedAt: record.updatedAt,
            version: record.version
        )
    }

    func updateNote(_ note: WatchNoteSummary, title: String, content: String) async throws -> WatchNoteSummary {
        let actorID = try await currentUserID()
        let now = Date()

        let record: WatchNoteRecord = try await client
            .from("notes")
            .update(
                WatchNoteUpdatePayload(
                    title: title,
                    content: content,
                    updated_by: actorID,
                    updated_at: now,
                    version: note.version + 1
                )
            )
            .eq("id", value: note.id)
            .select("id, title, content, is_pinned, updated_at, version")
            .single()
            .execute()
            .value

        return WatchNoteSummary(
            id: record.id,
            title: record.title,
            content: record.content,
            isPinned: record.isPinned,
            updatedAt: record.updatedAt,
            version: record.version
        )
    }

    func deleteNote(_ note: WatchNoteSummary) async throws {
        let actorID = try await currentUserID()
        let now = Date()

        try await client
            .from("notes")
            .update(
                WatchSoftDeletePayload(
                    updated_by: actorID,
                    updated_at: now,
                    version: note.version + 1,
                    deleted_at: now
                )
            )
            .eq("id", value: note.id)
            .execute()
    }

    func fetchRoutines(spaceId: UUID) async throws -> [WatchRoutineSummary] {
        let records: [WatchRoutineRecord] = try await client
            .from("routines")
            .select("id, title, category, person_name, notes, start_minute_of_day, duration_minutes, active_weekdays, updated_at")
            .eq("space_id", value: spaceId)
            .is("deleted_at", value: nil)
            .order("start_minute_of_day", ascending: true)
            .execute()
            .value

        return records.map {
            WatchRoutineSummary(
                id: $0.id,
                title: $0.title,
                category: $0.category,
                personName: $0.personName,
                notes: $0.notes,
                startMinuteOfDay: $0.startMinuteOfDay,
                durationMinutes: $0.durationMinutes,
                activeWeekdaysRaw: $0.activeWeekdaysRaw,
                updatedAt: $0.updatedAt
            )
        }
    }

    func logRoutine(routineID: UUID, spaceID: UUID, note: String?) async throws {
        let actorID = try await currentUserID()
        let now = Date()

        try await client
            .from("routine_logs")
            .insert(
                WatchRoutineLogInsertPayload(
                    id: UUID(),
                    routine_id: routineID,
                    space_id: spaceID,
                    logged_at: now,
                    note: sanitizedOptionalText(note),
                    created_by: actorID,
                    updated_at: now,
                    version: 1
                )
            )
            .execute()
    }

    func fetchSavedPlaces(spaceId: UUID) async throws -> [WatchSavedPlaceSummary] {
        let records: [WatchSavedPlaceRecord] = try await client
            .from("saved_places")
            .select("id, name, description, category, address, latitude, longitude, radius_meters")
            .eq("space_id", value: spaceId)
            .is("deleted_at", value: nil)
            .order("name", ascending: true)
            .execute()
            .value

        return records.map {
            WatchSavedPlaceSummary(
                id: $0.id,
                name: $0.name,
                description: $0.description,
                category: $0.category,
                address: $0.address,
                latitude: $0.latitude,
                longitude: $0.longitude,
                radiusMeters: $0.radiusMeters
            )
        }
    }

    func fetchPeople(spaceId: UUID) async throws -> [WatchPersonSummary] {
        let records: [WatchSpaceMemberProfileRecord] = try await client
            .from("space_members")
            .select("user_id, role, profiles(email, full_name)")
            .eq("space_id", value: spaceId)
            .execute()
            .value

        return records
            .map {
                WatchPersonSummary(
                    id: $0.userId,
                    displayName: $0.profile?.fullName?.nonEmpty ?? $0.profile?.email ?? String(localized: "watch.people.unknown"),
                    email: $0.profile?.email ?? "",
                    role: $0.role
                )
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func fetchMission(id: UUID) async throws -> WatchMissionDetail {
        let record: WatchMissionDetailRecord = try await client
            .from("missions")
            .select("id, title, description, priority, is_completed, difficulty, due_date, saved_place_name, last_updated_at, version")
            .eq("id", value: id)
            .single()
            .execute()
            .value

        return WatchMissionDetail(
            id: record.id,
            title: record.title,
            description: record.description,
            priority: record.priority,
            isCompleted: record.isCompleted,
            difficulty: record.difficulty,
            dueDate: record.dueDate,
            savedPlaceName: record.savedPlaceName,
            updatedAt: record.lastUpdatedAt,
            version: record.version
        )
    }

    func setMissionCompleted(id: UUID, isCompleted: Bool, version: Int) async throws {
        let actorID = try await currentUserID()
        let now = Date()

        try await client
            .from("missions")
            .update(
                WatchMissionCompletionPayload(
                    is_completed: isCompleted,
                    updated_by: actorID,
                    updated_at: now,
                    last_updated_at: now,
                    version: version + 1
                )
            )
            .eq("id", value: id)
            .execute()
    }

    func fetchIncident(id: UUID) async throws -> WatchIncidentDetail {
        let record: WatchIncidentDetailRecord = try await client
            .from("incidents")
            .select("id, title, description, severity, status, occurrence_date, last_updated_at, version")
            .eq("id", value: id)
            .single()
            .execute()
            .value

        return WatchIncidentDetail(
            id: record.id,
            title: record.title,
            description: record.description,
            severity: record.severity,
            status: record.status,
            occurrenceDate: record.occurrenceDate,
            updatedAt: record.lastUpdatedAt,
            version: record.version
        )
    }

    func updateIncidentStatus(id: UUID, status: String, version: Int) async throws {
        let actorID = try await currentUserID()
        let now = Date()

        try await client
            .from("incidents")
            .update(
                WatchIncidentStatusPayload(
                    status: status,
                    updated_by: actorID,
                    updated_at: now,
                    last_updated_at: now,
                    version: version + 1
                )
            )
            .eq("id", value: id)
            .execute()
    }

    func addListItem(listID: UUID, title: String, position: Int) async throws {
        let actorID = try await currentUserID()
        let now = Date()

        try await client
            .from("shared_list_items")
            .insert(
                WatchSharedListItemInsertPayload(
                    id: UUID(),
                    list_id: listID,
                    title: title,
                    is_completed: false,
                    position: position,
                    updated_at: now,
                    version: 1,
                    updated_by: actorID
                )
            )
            .execute()
    }

    func toggleListItem(_ item: WatchSharedListItemSummary) async throws {
        let actorID = try await currentUserID()
        let now = Date()

        try await client
            .from("shared_list_items")
            .update(
                WatchSharedListItemUpdatePayload(
                    is_completed: !item.isCompleted,
                    updated_at: now,
                    version: item.version + 1,
                    updated_by: actorID
                )
            )
            .eq("id", value: item.id)
            .execute()
    }

    func deleteListItem(_ item: WatchSharedListItemSummary) async throws {
        let actorID = try await currentUserID()
        let now = Date()

        try await client
            .from("shared_list_items")
            .update(
                WatchSoftDeletePayload(
                    updated_by: actorID,
                    updated_at: now,
                    version: item.version + 1,
                    deleted_at: now
                )
            )
            .eq("id", value: item.id)
            .execute()
    }

    func registerCurrentDevice(authMethod: String, approvedVia: String?) async throws {
        WatchLog.msg("WatchSupabaseService.registerCurrentDevice method=\(authMethod) approvedVia=\(approvedVia ?? "nil")")
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
        WatchLog.msg("WatchSupabaseService.createPairingRequest started device=\(WatchKit.WKInterfaceDevice.current().name)")
        do {
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
        } catch {
            WatchLog.error(error)
            throw normalizePairingError(error)
        }
    }

    func claimPairingRequest(requestID: UUID, requestSecret: String) async throws -> WatchDevicePairingStatus {
        WatchLog.msg("WatchSupabaseService.claimPairingRequest request=\(requestID.uuidString)")
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

    private func normalizePairingError(_ error: Error) -> Error {
        let details = "\(error.localizedDescription) | \(String(describing: error))".lowercased()
        if details.contains("gen_random_bytes") {
            return WatchSupabaseServiceError.pairingBackendUnavailable
        }
        return error
    }

    private func currentUserID() async throws -> UUID {
        let session = try await client.auth.session
        return session.user.id
    }

    private func sanitizedOptionalText(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
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
    let version: Int

    enum CodingKeys: String, CodingKey {
        case id, title, position, version
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

private struct WatchNoteRecord: Decodable {
    let id: UUID
    let title: String
    let content: String
    let isPinned: Bool
    let updatedAt: Date?
    let version: Int

    enum CodingKeys: String, CodingKey {
        case id, title, content, version
        case isPinned = "is_pinned"
        case updatedAt = "updated_at"
    }
}

private struct WatchRoutineRecord: Decodable {
    let id: UUID
    let title: String
    let category: String
    let personName: String?
    let notes: String?
    let startMinuteOfDay: Int
    let durationMinutes: Int
    let activeWeekdaysRaw: String
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, category, notes
        case personName = "person_name"
        case startMinuteOfDay = "start_minute_of_day"
        case durationMinutes = "duration_minutes"
        case activeWeekdaysRaw = "active_weekdays"
        case updatedAt = "updated_at"
    }
}

private struct WatchSavedPlaceRecord: Decodable {
    let id: UUID
    let name: String
    let description: String?
    let category: String?
    let address: String?
    let latitude: Double
    let longitude: Double
    let radiusMeters: Double

    enum CodingKeys: String, CodingKey {
        case id, name, description, category, address, latitude, longitude
        case radiusMeters = "radius_meters"
    }
}

private struct WatchSpaceMemberProfileRecord: Decodable {
    let userId: UUID
    let role: String
    let profile: WatchPersonProfileRecord?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case role
        case profile = "profiles"
    }
}

private struct WatchPersonProfileRecord: Decodable {
    let email: String?
    let fullName: String?

    enum CodingKeys: String, CodingKey {
        case email
        case fullName = "full_name"
    }
}

private struct WatchMissionDetailRecord: Decodable {
    let id: UUID
    let title: String
    let description: String
    let priority: String
    let isCompleted: Bool
    let difficulty: Int
    let dueDate: Date?
    let savedPlaceName: String?
    let lastUpdatedAt: Date?
    let version: Int

    enum CodingKeys: String, CodingKey {
        case id, title, description, priority, difficulty, version
        case isCompleted = "is_completed"
        case dueDate = "due_date"
        case savedPlaceName = "saved_place_name"
        case lastUpdatedAt = "last_updated_at"
    }
}

private struct WatchIncidentDetailRecord: Decodable {
    let id: UUID
    let title: String
    let description: String?
    let severity: String
    let status: String
    let occurrenceDate: Date
    let lastUpdatedAt: Date?
    let version: Int

    enum CodingKeys: String, CodingKey {
        case id, title, description, severity, status, version
        case occurrenceDate = "occurrence_date"
        case lastUpdatedAt = "last_updated_at"
    }
}

private struct WatchNoteInsertPayload: Encodable {
    let id: UUID
    let space_id: UUID
    let title: String
    let content: String
    let created_by: UUID?
    let updated_by: UUID?
    let updated_at: Date
    let version: Int
}

private struct WatchNoteUpdatePayload: Encodable {
    let title: String
    let content: String
    let updated_by: UUID?
    let updated_at: Date
    let version: Int
}

private struct WatchRoutineLogInsertPayload: Encodable {
    let id: UUID
    let routine_id: UUID
    let space_id: UUID
    let logged_at: Date
    let note: String?
    let created_by: UUID?
    let updated_at: Date
    let version: Int
}

private struct WatchMissionCompletionPayload: Encodable {
    let is_completed: Bool
    let updated_by: UUID?
    let updated_at: Date
    let last_updated_at: Date
    let version: Int
}

private struct WatchIncidentStatusPayload: Encodable {
    let status: String
    let updated_by: UUID?
    let updated_at: Date
    let last_updated_at: Date
    let version: Int
}

private struct WatchSharedListItemInsertPayload: Encodable {
    let id: UUID
    let list_id: UUID
    let title: String
    let is_completed: Bool
    let position: Int
    let updated_at: Date
    let version: Int
    let updated_by: UUID?
}

private struct WatchSharedListItemUpdatePayload: Encodable {
    let is_completed: Bool
    let updated_at: Date
    let version: Int
    let updated_by: UUID?
}

private struct WatchSoftDeletePayload: Encodable {
    let updated_by: UUID?
    let updated_at: Date
    let version: Int
    let deleted_at: Date
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
    case pairingBackendUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidSessionIdentifier:
            return String(localized: "watch.auth.error.invalidSession")
        case .pairingBackendUnavailable:
            return String(localized: "watch.auth.code.error.backendUnavailable")
        }
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#endif
