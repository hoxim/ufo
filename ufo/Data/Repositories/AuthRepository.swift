//
//  AuthRepository.swift
//  ufo
//
//  Created by Marcin Ryzko on 29/01/2026.
//

import Foundation
import Supabase
import SwiftData
import UniformTypeIdentifiers

@Observable
final class AuthRepository: AuthRepositoryProtocol {
    
    var isLoggedIn: Bool = false
    var isBusy: Bool = false
    var currentUser: UserProfile? // Your SwiftData Domain Model
    
    private let client: SupabaseClient
    
    init(client: SupabaseClient, isLoggedIn: Bool = false, currentUser: UserProfile? = nil) {
        self.client = client
        self.isLoggedIn = isLoggedIn
        self.currentUser = currentUser
    }
    
    /**
     Checks whether an auth session exists and is still valid.

     If a non-expired session is found, this method fetches the user profile and updates local state.
     If no session exists or the session is expired, it signs the user out and clears local state.

     - Note: This method toggles `isBusy` while it runs and updates state on the main actor when signing out.

     ### Example
     ```swift
     await authRepository.checkAuthStatus()
     ```
     */
    func checkAuthStatus() async {
        isBusy = true
        defer { isBusy = false }

        do {
            let session = try await client.auth.session
            
            guard !session.isExpired else {
                Log.msg("Session expired")
                await signOut()
                return
            }

            try await fetchUserProfile(id: session.user.id)

        } catch {
            Log.msg("No active session found: \(error.localizedDescription)")
            await signOut()
        }
    }
    
    func signIn(email: String, password: String) async throws {
        isBusy = true
        defer { isBusy = false }
        
        Log.msg("Starting sign in flow for: \(email)")
        
        do {
            // 1. Authenticate with Supabase Auth
            let session = try await client.auth.signIn(email: email, password: password)
            let userId = session.user.id
            
            Log.msg("Auth successful. Fetching profile and spaces data...")
            
            // 2. Fetch Profile + Memberships + Spaces
            try await fetchUserProfile(id: userId)
            
        } catch {
            Log.error(error)
            throw error
        }
    }
    
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
        
        try await fetchUserProfile(id: userId)
    }
    
    func fetchUserProfile(id: UUID) async throws {
        do {
            let profileDTO: UserProfileDTO = try await client
                .from("profiles")
                .select("*, space_members(*, spaces(*))")
                .eq("id", value: id)
                .single()
                .execute()
                .value
            
            Log.msg("Profile fetched: \(profileDTO.fullName ?? "No Name"). Syncing with SwiftData...")
            
            syncWithSwiftData(dto: profileDTO)
            
        } catch {
            Log.error(error)
            throw error
        }
    }

    @MainActor
    private func syncWithSwiftData(dto: UserProfileDTO) {
        // 1. Create UserProfile (Domain Model)
        let userProfile = UserProfile(
            id: dto.id,
            email: dto.email ?? "",
            fullName: dto.fullName,
            role: "user"
        )
        
        // 2. Map Memberships and Spaces
        if let membersDTO = dto.spaceMembers {
            var memberships: [SpaceMembership] = []
            
            for memberDTO in membersDTO {
                if let spaceDTO = memberDTO.space {
                    // Create Space Model
                    let space = Space(
                        id: spaceDTO.id,
                        name: spaceDTO.name,
                        inviteCode: spaceDTO.inviteCode
                    )
                    
                    // Create Membership Model
                    let membership = SpaceMembership(
                        user: userProfile,
                        space: space,
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

    func uploadAvatar(imageData: Data, fileName: String) async throws {
        guard let userId = currentUser?.id else { return }
        
        // 1. Upload do Supabase Storage
        let fileExtension = fileName.split(separator: ".").last.map(String.init) ?? "jpg"
        let type = UTType(filenameExtension: fileExtension) ?? .jpeg
        let storagePath = "avatars/\(userId.uuidString).\(fileExtension)"
        
        try await client.storage
            .from("avatars")
            .upload(
                storagePath,
                data: imageData,
                options: FileOptions(contentType: type.preferredMIMEType)
            )
        
        // 2. get public URL
        let publicURL = try client.storage
            .from("avatars")
            .getPublicURL(path: storagePath)
        
        // 3. update supabase
        try await client
            .from("profiles")
            .update(["avatar_url": publicURL.absoluteString])
            .eq("id", value: userId)
            .execute()
        
        // 4. refresh local model
        await MainActor.run {
            currentUser?.avatarURL = publicURL.absoluteString
        }
    }
}

// Simple Error Enum
enum AuthError: Error {
    case notAuthenticated
}
