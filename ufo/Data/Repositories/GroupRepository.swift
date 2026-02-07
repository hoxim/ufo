//
//  GroupRepository.swift
//  ufo
//
//  Created by Marcin Ryzko on 30/01/2026.
//

import Foundation
import Observation
import Supabase

@Observable
final class GroupRepository {
    private let client: SupabaseClient
    var pendingInvitation: GroupInvitation?
    init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - Create Group
    /// Creates a new group and automatically adds the creator as an Admin.
    func createGroup(name: String, type: String = "Family") async throws {
        guard let userId = client.auth.currentUser?.id else {
            throw AuthError.notAuthenticated
        }
        
        let inviteCode = String(UUID().uuidString.prefix(6)).uppercased()
        Log.msg("Creating group: \(name) of type: \(type)")
        
        // 1. Insert Group (Added 'type' to the payload)
        struct NewGroup: Encodable {
            let name: String
            let invite_code: String
            let type: String
        }
        
        let newGroup: GroupDTO = try await client
            .from("groups")
            .insert(NewGroup(name: name, invite_code: inviteCode, type: type))
            .select()
            .single()
            .execute()
            .value
            
        // 2. Add creator as Admin
        struct NewMember: Encodable {
            let user_id: UUID
            let group_id: UUID
            let role: String
        }
        
        try await client
            .from("group_members")
            .insert(NewMember(user_id: userId, group_id: newGroup.id, role: "admin"))
            .execute()
            
        Log.msg("Group created and Admin assigned.")
        
        // 3. IMPORTANT: Refresh user profile to show the new group in RootView immediately
        // Since we are in GroupRepository, we rely on the next app refresh or
        // we can use a callback/notification to tell AuthRepository to reload.
    }
    
    // MARK: - Join Group
    /// Joins an existing group using an invite code.
    func joinGroup(inviteCode: String) async throws {
        guard let userId = client.auth.currentUser?.id else {
            throw AuthError.notAuthenticated
        }
        
        Log.msg("Joining group with code: \(inviteCode)")
        
        // 1. Find group by code
        let group: GroupDTO = try await client
            .from("groups")
            .select()
            .eq("invite_code", value: inviteCode)
            .single()
            .execute()
            .value
            
        // 2. Insert Membership (default role: member)
        struct NewMember: Encodable {
            let user_id: UUID
            let group_id: UUID
            let role: String
        }
        
        try await client
            .from("group_members")
            .insert(NewMember(user_id: userId, group_id: group.id, role: "member"))
            .execute()
            
        Log.msg("Successfully joined group: \(group.name)")
    }
    
    // MARK: - Leave Group
    /// Leaves a specific group by removing the membership record.
    func leaveGroup(groupId: UUID) async throws {
        guard let userId = client.auth.currentUser?.id else {
            throw AuthError.notAuthenticated
        }
        
        Log.msg("Leaving group: \(groupId)")
        
        try await client
            .from("group_members")
            .delete()
            .eq("group_id", value: groupId)
            .eq("user_id", value: userId)
            .execute()
            
        Log.msg("Left group successfully.")
    }
    
    // MARK: - Remote Checks
    /// Checks for pending invitations for a specific email address
    func checkInvites(for email: String) async throws {
        // Implementation logic:
        // 1. Query 'group_invitations' table where invitee_email == email
        // 2. If found, fetch group details and set pendingInvitation
        
        Log.msg("Checking invitations for: \(email)")
        
        // Placeholder for the actual Supabase query
        // let inviteDTO = try await client.from("group_invitations")...
    }
    
    // MARK: - Actions
    func acceptInvitation(_ invitation: GroupInvitation) async throws {
        // Logic to add user to group_members and delete the invitation
        self.pendingInvitation = nil
    }
    
    func rejectInvitation(_ invitation: GroupInvitation) async throws {
        // Logic to delete the invitation
        self.pendingInvitation = nil
    }
    
    // MARK: - Invitations
    /// Creates an invitation record (optional, if you want to track sent invites via email).
    /// Note: Users can also just share the 'inviteCode' from the Group model directly.
    func createInvitation(groupId: UUID, email: String) async throws {
        guard let userId = client.auth.currentUser?.id else {
            throw AuthError.notAuthenticated
        }
        
        Log.msg("Sending invitation to: \(email)")
        
        // Assuming you have a 'group_invitations' table as discussed previously
        struct NewInvitation: Encodable {
            let group_id: UUID
            let inviter_id: UUID // The current user
            let invitee_email: String
            let invite_code: String // Generated specifically for this invite
        }
        
        let uniqueCode = String(UUID().uuidString.prefix(8)).uppercased()
        
        try await client
            .from("group_invitations")
            .insert(NewInvitation(
                group_id: groupId,
                inviter_id: userId,
                invitee_email: email,
                invite_code: uniqueCode
            ))
            .execute()
            
        Log.msg("Invitation created in database.")
    }
}
