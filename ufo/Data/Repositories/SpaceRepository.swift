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
    
    var currentSpaceId: UUID? {
        selectedSpace?.id
    }
    
    func selectFirstSpace(from userSpaces: [Space]) {
        if selectedSpace == nil {
            self.selectedSpace = userSpaces.first
        }
    }
    
    func restoreLastSelectedSpace(from userSpaces: [Space]) {
        if let savedIdString = UserDefaults.standard.string(forKey: lastSpaceIdKey),
           let savedId = UUID(uuidString: savedIdString),
           let matchedSpace = userSpaces.first(where: { $0.id == savedId }) {
            
            self.selectedSpace = matchedSpace
            Log.msg("Restored last session space: \(matchedSpace.name)")
        } else {
            self.selectedSpace = nil
        }
    }

    func getSpaces() async throws -> [Space] {
        guard let userId = client.auth.currentUser?.id else {
            throw AuthError.notAuthenticated
        }
        
        Log.msg("🛸 Fetching spaces for user: \(userId)")
        
        let memberships: [SpaceMemberDTO] = try await client
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

    func fetchAll() async throws -> [Space] {
        try await getSpaces()
    }

    func fetchById(_ id: UUID) async throws -> Space? {
        let result: SpaceDTO? = try await client
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

    func fetchMembers(spaceId: UUID) async throws -> [SpaceMemberDTO] {
        try await client
            .from("space_members")
            .select("user_id, role, joined_at, profiles(*), spaces(*)")
            .eq("space_id", value: spaceId)
            .execute()
            .value
    }

    func fetchRecipients(spaceId: UUID) async throws -> [SpaceMemberRecipient] {
        let members = try await fetchMembers(spaceId: spaceId)
        return members.map { member in
            SpaceMemberRecipient(
                id: member.userId,
                email: member.profile?.email ?? "",
                fullName: member.profile?.fullName,
                avatarURL: member.profile?.avatarUrl,
                role: member.role
            )
        }
    }

    func fetchInvitations(for email: String, status: String = "pending") async throws -> [SpaceInvitationDTO] {
        try await client
            .from("space_invitations")
            .select("*, spaces(*)")
            .eq("invitee_email", value: email.lowercased())
            .eq("status", value: status)
            .execute()
            .value
    }

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
            
            let newSpace: SpaceDTO = try await client
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

    func ensurePersonalSpaceIfNeeded(for spaces: [Space]) async throws {
        guard spaces.isEmpty else { return }
        try await createSpace(name: "Personal Space", type: .personal)
    }
    
    func joinSpace(inviteCode: String) async throws {
        guard let userId = client.auth.currentUser?.id else {
            throw AuthError.notAuthenticated
        }
        
        Log.msg("Joining space with code: \(inviteCode)")
        
        // 1. Find space by code
        let space: SpaceDTO = try await client
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

    func deleteSpace(spaceId: UUID) async throws {
        try await client
            .from("spaces")
            .delete()
            .eq("id", value: spaceId)
            .execute()
    }

    func checkInvites(for email: String) async throws {
        guard pendingInvitation == nil && !isCheckingInvites else { return }
            
        isCheckingInvites = true
        defer { isCheckingInvites = false }
        
        do {
            let invitesDTO: [SpaceInvitationDTO] = try await client
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
    
    func createInvitation(spaceId: UUID, email: String) async throws {
        guard let userId = client.auth.currentUser?.id else {
            throw AuthError.notAuthenticated
        }

        guard let space = try await fetchById(spaceId), space.allowsInvitations else {
            throw SpaceError.invitationsBlockedForPrivateSpace
        }
        
        Log.msg("Sending invitation to: \(email)")
        
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

    func inviteMember(email: String, spaceId: UUID) async throws {
        guard let userId = client.auth.currentUser?.id else {
            throw AuthError.notAuthenticated
        }

        guard let space = try await fetchById(spaceId), space.allowsInvitations else {
            throw SpaceError.invitationsBlockedForPrivateSpace
        }
        
        Log.msg("🛸 Initiating transmission to: \(email)")
        
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
            return "Do Space typu Private nie można wysyłać zaproszeń. Utwórz Space typu Shared."
        }
    }
}
