//
//  AuthRepository.swift
//  ufo
//
//  Created by Marcin Ryzko on 29/01/2026.
//

import Foundation
import Supabase
import SwiftData

@Observable
final class AuthRepository: AuthRepositoryProtocol {
    
    // MARK: - Properties
    var isLoggedIn: Bool = false
    var isBusy: Bool = false
    var currentUser: UserProfile? // Your SwiftData Domain Model
    
    private let client: SupabaseClient
    
    // MARK: - Init
    init(client: SupabaseClient) {
        self.client = client
    }
    
    // MARK: - Auth Status Check (App Launch)
    
    /// Checks if a session exists in the Keychain on app launch.
    func checkAuthStatus() async {
        isBusy = true
        defer { isBusy = false }
        
        do {
            // Check for existing session
            let session = try await client.auth.session
            Log.msg("Session found. Fetching full profile for: \(session.user.id)")
            
            // If session exists, fetch the profile and groups
            try await fetchUserProfile(id: session.user.id)
            
        } catch {
            Log.msg("No active session found or fetch failed: \(error.localizedDescription)")
            await signOut() // Clean up state if session is invalid
        }
    }
    
    // MARK: - Sign In
    
    func signIn(email: String, password: String) async throws {
        isBusy = true
        defer { isBusy = false }
        
        Log.msg("Starting sign in flow for: \(email)")
        
        do {
            // 1. Authenticate with Supabase Auth
            let session = try await client.auth.signIn(email: email, password: password)
            let userId = session.user.id
            
            Log.msg("Auth successful. Fetching profile and groups data...")
            
            // 2. Fetch Profile + Memberships + Groups
            try await fetchUserProfile(id: userId)
            
        } catch {
            Log.error(error)
            throw error
        }
    }
    
    // MARK: - Sign Up
    
    /// Minimal registration using only email and password.
    func signUp(email: String, password: String) async throws {
        isBusy = true
        defer { isBusy = false }
        
        Log.msg("Starting registration for: \(email)")
        do{
            
            // We do NOT send metadata here. The SQL Trigger will create an empty profile row.
            let result = try await client.auth.signUp(
                email: email,
                password: password
            )
            
            if let identities = result.user.identities, identities.isEmpty {
                Log.msg("Your account already exists, please log in")
            }else{
                Log.msg("Registration successful. Verification email sent (if enabled).")
            }
            
        } catch {
            Log.error(error)
            throw error
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() async {
        do {
            try await client.auth.signOut()
            Log.msg("User signed out from Supabase.")
        } catch {
            Log.error(error)
        }
        
        // Clear local state
        await MainActor.run {
            self.currentUser = nil
            self.isLoggedIn = false
        }
    }
    
    // MARK: - Profile Management (Onboarding)
    
    /// Updates the user's name and avatar. Used during Onboarding.
    func completeProfile(fullName: String, avatarUrl: String? = nil) async throws {
        guard let userId = client.auth.currentUser?.id else {
            throw AuthError.notAuthenticated
        }
        
        isBusy = true
        defer { isBusy = false }
        
        Log.msg("Updating profile for user ID: \(userId)")
        
        struct UpdateProfilePayload: Encodable {
            let full_name: String
            let avatar_url: String?
        }
        
        let payload = UpdateProfilePayload(full_name: fullName, avatar_url: avatarUrl)
        
        try await client
            .from("profiles")
            .update(payload)
            .eq("id", value: userId)
            .execute()
            
        Log.msg("Profile updated on server. Refreshing local data...")
        
        // Refresh local state to reflect changes immediately
        try await fetchUserProfile(id: userId)
    }
    
    // MARK: - Data Fetching & Sync
    
    /// Fetches the complete user profile including group memberships and nested group details.
    func fetchUserProfile(id: UUID) async throws {
        do {
            // Fetch raw data from Supabase (Profile + Memberships + Groups)
            // This query joins 3 tables: profiles -> group_members -> groups
            let profileDTO: UserProfileDTO = try await client
                .from("profiles")
                .select("*, group_members(*, groups(*))")
                .eq("id", value: id)
                .single()
                .execute()
                .value
            
            Log.msg("Profile fetched: \(profileDTO.fullName ?? "No Name"). Syncing with SwiftData...")
            
            // Sync with local state
            syncWithSwiftData(dto: profileDTO)
            
        } catch {
            Log.error(error)
            throw error
        }
    }

    /// Maps the DTO to the Domain Model and updates the local state.
    @MainActor
    private func syncWithSwiftData(dto: UserProfileDTO) {
        // 1. Create UserProfile (Domain Model)
        let userProfile = UserProfile(
            id: dto.id,
            email: dto.email ?? "",
            fullName: dto.fullName,
            role: "user"
        )
        
        // 2. Map Memberships and Groups
        if let membersDTO = dto.groupMembers {
            var memberships: [GroupMembership] = []
            
            for memberDTO in membersDTO {
                if let groupDTO = memberDTO.group {
                    // Create Group Model
                    let group = Group(
                        id: groupDTO.id,
                        name: groupDTO.name,
                        inviteCode: groupDTO.inviteCode
                    )
                    
                    // Create Membership Model
                    let membership = GroupMembership(
                        user: userProfile,
                        group: group,
                        role: memberDTO.role
                    )
                    
                    memberships.append(membership)
                }
            }
            userProfile.memberships = memberships
        }
        
        // 3. Update State
        self.currentUser = userProfile
        self.isLoggedIn = true
        Log.msg("Local state updated. User is logged in.")
    }
}

// Simple Error Enum
enum AuthError: Error {
    case notAuthenticated
}
