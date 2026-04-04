//
//  SpaceRepository.swift
//  ufo
//
//  Created by Marcin Ryzko on 30/01/2026.
//

import Foundation
import Observation
import Supabase

@Observable
final class SpaceRepository {
    private let client: SupabaseClient
    private let lastSpaceIdKey = "last_selected_space_id"
    var pendingInvitation: SpaceInvitation?
    var isCheckingInvites = false
    var selectedSpace: Space? {
        didSet {
            if let space = selectedSpace {
                UserDefaults.standard.set(space.id.uuidString, forKey: lastSpaceIdKey)
                Log.msg("Selected space changed to: \(space.name)")
            } else {
                UserDefaults.standard.removeObject(forKey: lastSpaceIdKey)
            }
        }
    }
    
    init(client: SupabaseClient) {
        self.client = client
    }

    private struct SpaceRecord: Codable {
        let id: UUID
        let name: String
        let inviteCode: String
        let category: String?
        let version: Int?
        let updatedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id, name, category, version
            case inviteCode = "invite_code"
            case updatedAt = "updated_at"
        }
    }

    private struct SpaceMemberUserRecord: Codable {
        let id: UUID
        let email: String?
        let fullName: String?
        let avatarUrl: String?
        let providerAvatarUrl: String?

        enum CodingKeys: String, CodingKey {
            case id, email
            case fullName = "full_name"
            case avatarUrl = "avatar_url"
            case providerAvatarUrl = "provider_avatar_url"
        }
    }

    private struct SpaceMemberRecord: Codable {
        let userId: UUID
        let role: String
        let joinedAt: Date
        let profile: SpaceMemberUserRecord?
        let space: SpaceRecord?

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case role
            case joinedAt = "joined_at"
            case profile = "profiles"
            case space = "spaces"
        }
    }

    private struct SpaceInvitationRecord: Codable {
        let id: UUID
        let spaceId: UUID
        let inviterId: UUID?
        let inviteeEmail: String
        let inviteCode: String
        let status: String
        let sentAt: Date
        let expiresAt: Date?
        let space: SpaceRecord?

        enum CodingKeys: String, CodingKey {
            case id, status
            case spaceId = "space_id"
            case inviterId = "inviter_id"
            case inviteeEmail = "invitee_email"
            case inviteCode = "invite_code"
            case sentAt = "sent_at"
            case expiresAt = "expires_at"
            case space = "spaces"
        }
    }
    
    var currentSpaceId: UUID? {
        selectedSpace?.id
    }
    
    /// Handles select first space.
    func selectFirstSpace(from userSpaces: [Space]) {
        if selectedSpace == nil {
            setSelectedSpace(userSpaces.first)
        }
    }
    
    /// Restores last selected space.
    func restoreLastSelectedSpace(from userSpaces: [Space]) {
        if let savedIdString = UserDefaults.standard.string(forKey: lastSpaceIdKey),
           let savedId = UUID(uuidString: savedIdString),
           let matchedSpace = userSpaces.first(where: { $0.id == savedId }) {
            
            setSelectedSpace(matchedSpace)
            Log.msg("Restored last session space: \(matchedSpace.name)")
        } else if selectedSpace == nil {
            setSelectedSpace(nil)
        }
    }

    private func setSelectedSpace(_ newValue: Space?) {
        if selectedSpace?.id == newValue?.id {
            return
        }
        selectedSpace = newValue
    }

    /// Handles get spaces.
    func getSpaces() async throws -> [Space] {
        guard let userId = client.auth.currentUser?.id else {
            throw AuthError.notAuthenticated
        }
        
        Log.msg("🛸 Fetching spaces for user: \(userId)")
        
        let memberships: [SpaceMemberRecord] = try await client
            .from("space_members")
            .select("user_id, role, joined_at, spaces(*)")
            .eq("user_id", value: userId)
            .execute()
            .value
        
        let userSpaces = memberships.compactMap { memberDTO -> Space? in
            guard let g = memberDTO.space else { return nil }
            return Space(
                id: g.id,
                name: g.name,
                inviteCode: g.inviteCode,
                category: g.category ?? SpaceType.shared.rawValue,
                updatedAt: g.updatedAt ?? .now,
                version: g.version ?? 1
            )
        }
        
        Log.msg("✅ Successfully retrieved \(userSpaces.count) spaces.")
        return userSpaces
    }

    /// Fetches all.
    func fetchAll() async throws -> [Space] {
        try await getSpaces()
    }

    /// Fetches by id.
    func fetchById(_ id: UUID) async throws -> Space? {
        let result: SpaceRecord? = try await client
            .from("spaces")
            .select("*")
            .eq("id", value: id)
            .single()
            .execute()
            .value

        guard let result else { return nil }
        return Space(
            id: result.id,
            name: result.name,
            inviteCode: result.inviteCode,
            category: result.category ?? SpaceType.shared.rawValue,
            updatedAt: result.updatedAt ?? .now,
            version: result.version ?? 1
        )
    }

    /// Fetches members.
    func fetchMembers(spaceId: UUID) async throws -> [SpaceMemberRecipient] {
        let members: [SpaceMemberRecord] = try await client
            .from("space_members")
            .select("user_id, role, joined_at, profiles(*), spaces(*)")
            .eq("space_id", value: spaceId)
            .execute()
            .value

        return members.map { member in
            SpaceMemberRecipient(
                id: member.userId,
                email: member.profile?.email ?? "",
                fullName: member.profile?.fullName,
                avatarURL: member.profile?.avatarUrl,
                providerAvatarURL: member.profile?.providerAvatarUrl,
                role: member.role
            )
        }
    }

    /// Fetches recipients.
    func fetchRecipients(spaceId: UUID) async throws -> [SpaceMemberRecipient] {
        try await fetchMembers(spaceId: spaceId)
    }

    /// Updates role for a space member.
    func updateMemberRole(spaceId: UUID, userId: UUID, role: String) async throws {
        struct RoleUpdate: Encodable {
            let role: String
        }

        try await client
            .from("space_members")
            .update(RoleUpdate(role: role))
            .eq("space_id", value: spaceId)
            .eq("user_id", value: userId)
            .execute()
    }

    /// Fetches invitations.
    func fetchInvitations(for email: String, status: String = "pending") async throws -> [SpaceInvitation] {
        let invites: [SpaceInvitationRecord] = try await client
            .from("space_invitations")
            .select("*, spaces(*)")
            .eq("invitee_email", value: email.lowercased())
            .eq("status", value: status)
            .execute()
            .value

        return invites.map { dto in
            SpaceInvitation(
                id: dto.id,
                spaceId: dto.spaceId,
                inviterId: dto.inviterId,
                inviteeEmail: dto.inviteeEmail,
                inviteCode: dto.inviteCode,
                status: dto.status,
                sentAt: dto.sentAt,
                expiresAt: dto.expiresAt,
                spaceName: dto.space?.name ?? "Unknown Space"
            )
        }
    }

    /// Creates space.
    func createSpace(name: String = "My Space", type: SpaceType = .personal) async throws {
            guard let userId = client.auth.currentUser?.id else {
                throw AuthError.notAuthenticated
            }
            
            let inviteCode = String(UUID().uuidString.prefix(6)).uppercased()
            Log.msg("Creating space: \(name) of type: \(type.rawValue)")
            
            struct NewSpace: Encodable {
                let name: String
                let invite_code: String
                let category: String
            }
            
            let newSpace: SpaceRecord = try await client
                .from("spaces")
                .insert(
                    NewSpace(
                        name: name,
                        invite_code: inviteCode,
                        category: type.rawValue
                    )
                )
                .select()
                .single()
                .execute()
                .value
                
            // 2. we add creator as an Admin
            struct NewMember: Encodable {
                let user_id: UUID
                let space_id: UUID
                let role: String
            }
            
            try await client
                .from("space_members")
                .insert(NewMember(user_id: userId, space_id: newSpace.id, role: "admin"))
                .execute()
                
            Log.msg("Space created and Admin assigned.")
        }

    /// Handles ensure personal space if needed.
    func ensurePersonalSpaceIfNeeded(for spaces: [Space]) async throws {
        guard spaces.isEmpty else { return }
        try await createSpace(name: "Personal Space", type: .personal)
    }
    
    /// Handles join space.
    func joinSpace(inviteCode: String) async throws {
        guard let userId = client.auth.currentUser?.id else {
            throw AuthError.notAuthenticated
        }
        
        Log.msg("Joining space by invite code.")
        
        // 1. Find space by code
        let space: SpaceRecord = try await client
            .from("spaces")
            .select()
            .eq("invite_code", value: inviteCode)
            .single()
            .execute()
            .value
            
        // 2. Insert Membership (default role: member)
        struct NewMember: Encodable {
            let user_id: UUID
            let space_id: UUID
            let role: String
        }
        
        try await client
            .from("space_members")
            .insert(NewMember(user_id: userId, space_id: space.id, role: "member"))
            .execute()
            
        Log.msg("Successfully joined space: \(space.name)")
    }

    /// Handles leave space.
    func leaveSpace(spaceId: UUID) async throws {
        guard let userId = client.auth.currentUser?.id else {
            throw AuthError.notAuthenticated
        }
        
        Log.msg("Leaving space: \(spaceId)")
        
        try await client
            .from("space_members")
            .delete()
            .eq("space_id", value: spaceId)
            .eq("user_id", value: userId)
            .execute()
            
        Log.msg("Left space successfully.")
    }

    /// Deletes space.
    func deleteSpace(spaceId: UUID) async throws {
        try await client
            .from("spaces")
            .delete()
            .eq("id", value: spaceId)
            .execute()
    }

    /// Checks invites.
    func checkInvites(for email: String) async throws {
        guard pendingInvitation == nil && !isCheckingInvites else { return }
            
        isCheckingInvites = true
        defer { isCheckingInvites = false }
        
        do {
            let invitesDTO: [SpaceInvitationRecord] = try await client
                .from("space_invitations")
                .select("*, spaces(*)")
                .eq("invitee_email", value: email.lowercased())
                .eq("status", value: "pending")
                .execute()
                .value
            
            if let dto = invitesDTO.first, let spaceDTO = dto.space {
                
                let invite = SpaceInvitation(
                    id: dto.id,
                    spaceId: spaceDTO.id,
                    inviterId: dto.inviterId,
                    inviteeEmail: dto.inviteeEmail,
                    inviteCode: dto.inviteCode,
                    status: dto.status,
                    sentAt: dto.sentAt,
                    expiresAt: dto.expiresAt,
                    spaceName: spaceDTO.name
                )
                
                await MainActor.run {
                    self.pendingInvitation = invite
                    Log.msg("📬 UI Triggered: Invitation found for \(spaceDTO.name)")
                }
            }
        } catch {
            Log.error("Error checking invites: \(error.localizedDescription)")
        }
    }
    
    /// Handles accept invitation.
    func acceptInvitation(_ invitation: SpaceInvitation) async throws {
        guard let userId = client.auth.currentUser?.id else {
            throw AuthError.notAuthenticated
        }
        
        Log.msg("📥 Accepting invitation to space: \(invitation.spaceName)")
        
        let response = try await client
            .from("space_invitations")
            .update(["status": "accepted"])
            .eq("id", value: invitation.id)
            .execute()
        
        Log.msg("📡 DB Update status code: \(response.status)")
        
        struct NewMember: Encodable {
            let user_id: UUID
            let space_id: UUID
            let role: String
        }
        
        try await client
            .from("space_members")
            .insert(NewMember(
                user_id: userId,
                space_id: invitation.spaceId,
                role: "member"
            ))
            .execute()
        
        await MainActor.run {
            self.pendingInvitation = nil
            Log.msg("✅ Joined space and updated status.")
        }
    }
    
    /// Handles reject invitation.
    func rejectInvitation(_ invitation: SpaceInvitation) async throws {
        Log.msg("🚫 Rejecting invitation from space: \(invitation.spaceName)")
        
        try await client
            .from("space_invitations")
            .update(["status": "rejected"])
            .eq("id", value: invitation.id)
            .execute()
        
        await MainActor.run {
            self.pendingInvitation = nil
            Log.msg("✅ Invitation rejected.")
        }
    }
    
    /// Creates invitation.
    func createInvitation(spaceId: UUID, email: String) async throws {
        guard let userId = client.auth.currentUser?.id else {
            throw AuthError.notAuthenticated
        }

        guard let space = try await fetchById(spaceId), space.allowsInvitations else {
            throw SpaceError.invitationsBlockedForPrivateSpace
        }
        
        Log.msg("Creating invitation for a new member.")
        
        struct NewInvitation: Encodable {
            let space_id: UUID
            let inviter_id: UUID
            let invitee_email: String
            let invite_code: String
        }
        
        let uniqueCode = String(UUID().uuidString.prefix(8)).uppercased()
        
        try await client
            .from("space_invitations")
            .insert(NewInvitation(
                space_id: spaceId,
                inviter_id: userId,
                invitee_email: email,
                invite_code: uniqueCode
            ))
            .execute()
            
        Log.msg("Invitation created in database.")
    }

    /// Handles invite member.
    func inviteMember(email: String, spaceId: UUID) async throws {
        guard let userId = client.auth.currentUser?.id else {
            throw AuthError.notAuthenticated
        }

        guard let space = try await fetchById(spaceId), space.allowsInvitations else {
            throw SpaceError.invitationsBlockedForPrivateSpace
        }
        
        Log.msg("Creating member invitation.")
        
        let uniqueCode = String(UUID().uuidString.prefix(8)).uppercased()
        
        struct NewInvitation: Encodable {
            let space_id: UUID
            let inviter_id: UUID
            let invitee_email: String
            let invite_code: String
            let status: String
        }
        
        let invitation = NewInvitation(
            space_id: spaceId,
            inviter_id: userId,
            invitee_email: email.lowercased().trimmingCharacters(in: .whitespaces),
            invite_code: uniqueCode,
            status: "pending"
        )
        
        try await client
            .from("space_invitations")
            .insert(invitation)
            .execute()
            
        Log.msg("✅ Transmission successful. Invite stored.")
    }
}

enum SpaceError: LocalizedError {
    case invitationsBlockedForPrivateSpace

    var errorDescription: String? {
        switch self {
        case .invitationsBlockedForPrivateSpace:
            return String(localized: "spaces.error.invitationsBlockedForPrivateSpace")
        }
    }
}
