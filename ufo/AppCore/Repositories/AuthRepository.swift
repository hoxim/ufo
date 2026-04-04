//
//  AuthRepository.swift
//  ufo
//
//  Created by Marcin Ryzko on 29/01/2026.
//

import Foundation
import Supabase
import Helpers
import SwiftData
import UniformTypeIdentifiers
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@Observable
final class AuthRepository: AuthRepositoryProtocol {
    
    var isLoggedIn: Bool = false
    var isBusy: Bool = false
    var currentUser: UserProfile? // Your SwiftData Domain Model
    
    private let client: SupabaseClient

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

    private struct SpaceMembershipRecord: Codable {
        let userId: UUID
        let role: String
        let joinedAt: Date
        let space: SpaceRecord?

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case role
            case joinedAt = "joined_at"
            case space = "spaces"
        }
    }

    private struct UserProfileRecord: Codable {
        let id: UUID
        let email: String?
        let fullName: String?
        let avatarUrl: String?
        let providerAvatarUrl: String?
        let providerFullName: String?
        let authProvider: String?
        let avatarVersion: Int?
        let spaceMembers: [SpaceMembershipRecord]?

        enum CodingKeys: String, CodingKey {
            case id, email
            case fullName = "full_name"
            case avatarUrl = "avatar_url"
            case providerAvatarUrl = "provider_avatar_url"
            case providerFullName = "provider_full_name"
            case authProvider = "auth_provider"
            case avatarVersion = "avatar_version"
            case spaceMembers = "space_members"
        }
    }

    private struct ProfileIdentityRecord: Decodable {
        let fullName: String?
        let avatarUrl: String?

        enum CodingKeys: String, CodingKey {
            case fullName = "full_name"
            case avatarUrl = "avatar_url"
        }
    }
    
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
    
    /// Handles sign in.
    func signIn(email: String, password: String) async throws {
        isBusy = true
        defer { isBusy = false }
        
        Log.msg("Starting sign in flow.")
        
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

    func currentSessionSnapshot() async throws -> AuthSessionSnapshot {
        let session = try await client.auth.session

        guard !session.isExpired else {
            throw AuthError.notAuthenticated
        }

        return AuthSessionSnapshot(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            userEmail: session.user.email
        )
    }

    /// Handles social sign in / sign up via OAuth provider.
    func signInWithOAuth(provider: SocialAuthProvider) async throws {
        isBusy = true
        defer { isBusy = false }

        let redirectURL = SupabaseConfig.redirectURL
        guard let callbackScheme = redirectURL.scheme, !callbackScheme.isEmpty else {
            throw AuthError.oauthInvalidRedirectConfiguration
        }
        let supabaseProvider = provider.supabaseProvider

        Log.msg("Starting OAuth sign in flow for provider=\(provider).")

        do {
            let authorizeURL = try client.auth.getOAuthSignInURL(
                provider: supabaseProvider,
                redirectTo: redirectURL
            )
            Log.msg("OAuth authorize URL host=\(authorizeURL.host ?? "nil") path=\(authorizeURL.path)")

            #if canImport(AuthenticationServices)
            let session = try await client.auth.signInWithOAuth(
                provider: supabaseProvider,
                redirectTo: redirectURL
            ) { @MainActor launchURL in
                Log.msg("Launching web auth session. callbackScheme=\(callbackScheme)")
                return try await Self.launchWebAuthenticationSession(
                    url: launchURL,
                    callbackScheme: callbackScheme
                )
            }
            #else
            let session = try await client.auth.signInWithOAuth(
                provider: supabaseProvider,
                redirectTo: redirectURL
            )
            #endif
            let userId = session.user.id

            try await syncOAuthProfile(user: session.user, provider: provider)
            Log.msg("OAuth auth successful. Fetching profile and spaces data...")
            try await fetchUserProfile(id: userId)
        } catch {
            if let nsError = error as NSError?,
               nsError.domain == "com.apple.AuthenticationServices.WebAuthenticationSession",
               nsError.code == 1 {
                Log.error("OAuth was cancelled or callback did not return to app. Verify redirect URL '\(redirectURL.absoluteString)' in Supabase Auth settings.")
            }
            Log.error(error)
            throw error
        }
    }

#if canImport(AuthenticationServices)
    @MainActor
    private static func launchWebAuthenticationSession(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let presentationContextProvider = OAuthPresentationContextProvider()
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error {
                    Log.error("ASWebAuthenticationSession completion error: \((error as NSError).domain) code=\((error as NSError).code)")
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL else {
                    continuation.resume(throwing: AuthError.oauthMissingCallbackURL)
                    return
                }

                Log.msg("OAuth callback received.")
                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = presentationContextProvider
            session.prefersEphemeralWebBrowserSession = false

            if !session.start() {
                continuation.resume(throwing: AuthError.oauthSessionStartFailed)
                return
            }

            // Keep strong refs alive for the whole auth session lifetime.
            _ = presentationContextProvider
            _ = session
        }
    }

    private final class OAuthPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            #if os(iOS)
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            guard let windowScene = scenes.first else {
                fatalError("No UIWindowScene available for OAuth presentation anchor.")
            }
            if let keyWindow = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
                return keyWindow
            }
            if let firstWindow = windowScene.windows.first {
                return firstWindow
            }
            return UIWindow(windowScene: windowScene)
            #elseif os(macOS)
            return NSApplication.shared.keyWindow ?? ASPresentationAnchor()
            #else
            return ASPresentationAnchor()
            #endif
        }
    }
#endif
    
    /// Handles sign up.
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
    
    /// Handles sign out.
    func signOut() async {
        do {
            try await client.auth.signOut(scope: .local)
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

    func signOutEverywhere() async {
        do {
            try await client.auth.signOut(scope: .global)
            Log.msg("User signed out from all Supabase sessions.")
        } catch {
            Log.error(error)
        }

        await MainActor.run {
            self.currentUser = nil
            self.isLoggedIn = false
        }
    }
    
    /// Handles complete profile.
    func completeProfile(fullName: String, avatarUrl: String? = nil) async throws {
        guard let userId = client.auth.currentUser?.id else {
            throw AuthError.notAuthenticated
        }
        
        isBusy = true
        defer { isBusy = false }
        
        Log.msg("Updating profile for user ID: \(userId)")
        
        do {
            if let avatarUrl {
                try await client
                    .from("profiles")
                    .update(["full_name": fullName, "avatar_url": avatarUrl])
                    .eq("id", value: userId)
                    .execute()
            } else {
                try await client
                    .from("profiles")
                    .update(["full_name": fullName])
                    .eq("id", value: userId)
                    .execute()
            }

            Log.msg("Profile updated on server. Refreshing local data...")
            try await fetchUserProfile(id: userId)
        } catch {
            Log.dbError("profiles.update (completeProfile)", error)
            throw error
        }
    }
    
    /// Fetches user profile.
    func fetchUserProfile(id: UUID) async throws {
        do {
            let profileDTO: UserProfileRecord = try await client
                .from("profiles")
                .select("*, space_members(*, spaces(*))")
                .eq("id", value: id)
                .single()
                .execute()
                .value
            
            Log.msg("Profile fetched: \(profileDTO.fullName ?? "No Name"). Syncing with SwiftData...")
            
            syncWithSwiftData(dto: profileDTO)
            await cacheAvatarIfNeeded(from: profileDTO)
            
        } catch {
            Log.dbError("profiles.select (fetchUserProfile)", error)
            throw error
        }
    }

    @MainActor
    /// Syncs with swift data.
    private func syncWithSwiftData(dto: UserProfileRecord) {
        // 1. Create UserProfile (Domain Model)
        let userProfile = UserProfile(
            id: dto.id,
            email: dto.email ?? "",
            fullName: dto.fullName,
            avatarVersion: dto.avatarVersion ?? 1,
            role: "user"
        )
        userProfile.avatarURL = dto.avatarUrl
        userProfile.providerAvatarURL = dto.providerAvatarUrl
        userProfile.providerFullName = dto.providerFullName
        userProfile.authProvider = dto.authProvider
        
        // 2. Map Memberships and Spaces
        if let membersDTO = dto.spaceMembers {
            var memberships: [SpaceMembership] = []
            
            for memberDTO in membersDTO {
                if let spaceDTO = memberDTO.space {
                    // Create Space Model
                    let space = Space(
                        id: spaceDTO.id,
                        name: spaceDTO.name,
                        inviteCode: spaceDTO.inviteCode,
                        category: spaceDTO.category ?? SpaceType.shared.rawValue,
                        updatedAt: spaceDTO.updatedAt ?? .now,
                        version: spaceDTO.version ?? 1
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

    /// Uploads avatar.
    func uploadAvatar(imageData: Data) async throws {
        guard let userId = currentUser?.id else { return }

        do {
            let preparedData = try prepareAvatarData(imageData)
            let storagePath = "avatar_\(userId.uuidString).jpg"

            try await client.storage
                .from("avatars")
                .upload(
                    storagePath,
                    data: preparedData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: UTType.jpeg.preferredMIMEType,
                        upsert: true
                    )
                )

            let publicURL = try client.storage
                .from("avatars")
                .getPublicURL(path: storagePath)

            let nextAvatarVersion = (currentUser?.avatarVersion ?? 1) + 1
            struct AvatarProfilePayload: Encodable {
                let avatar_url: String
                let avatar_version: Int
            }
            try await client
                .from("profiles")
                .update(
                    AvatarProfilePayload(
                        avatar_url: publicURL.absoluteString,
                        avatar_version: nextAvatarVersion
                    )
                )
                .eq("id", value: userId)
                .execute()

            AvatarCache.shared.store(preparedData, userId: userId, version: nextAvatarVersion)

            await MainActor.run {
                currentUser?.avatarURL = publicURL.absoluteString
                currentUser?.avatarVersion = nextAvatarVersion
            }
        } catch {
            Log.dbError("avatars.upload / profiles.update (uploadAvatar)", error)
            throw error
        }
    }

    /// Handles prepare avatar data.
    private func prepareAvatarData(_ data: Data) throws -> Data {
        let maxBytes = 1_000_000
        #if os(iOS)
        guard let image = UIImage(data: data) else {
            throw AuthError.avatarTooLarge
        }

        if let prepared = prepareJPEGUnderLimit(
            image: image,
            maxBytes: maxBytes,
            startingMaxDimension: 1024
        ) {
            return prepared
        }
        throw AuthError.avatarTooLarge
        #elseif os(macOS)
        guard
            let image = NSImage(data: data)
        else {
            throw AuthError.avatarTooLarge
        }

        if let prepared = prepareJPEGUnderLimit(
            image: image,
            maxBytes: maxBytes,
            startingMaxDimension: 1024
        ) {
            return prepared
        }
        throw AuthError.avatarTooLarge
        #else
        throw AuthError.avatarTooLarge
        #endif
    }

    /// Handles cache avatar if needed.
    private func cacheAvatarIfNeeded(from profile: UserProfileRecord) async {
        guard
            let avatarURL = profile.avatarUrl,
            let url = URL(string: avatarURL),
            let version = profile.avatarVersion,
            AvatarCache.shared.existingURL(userId: profile.id, version: version) == nil
        else {
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            AvatarCache.shared.store(data, userId: profile.id, version: version)
        } catch {
            Log.error("Avatar cache fetch failed: \(error.localizedDescription)")
        }
    }

    private func syncOAuthProfile(user: Auth.User, provider: SocialAuthProvider) async throws {
        let identity = mergedIdentityMetadata(from: user)
        let fullName = preferredOAuthFullName(from: user, identity: identity)
        let avatarURL = preferredOAuthAvatarURL(from: user, identity: identity)

        let existingProfile: ProfileIdentityRecord = try await client
            .from("profiles")
            .select("full_name, avatar_url")
            .eq("id", value: user.id)
            .single()
            .execute()
            .value

        struct OAuthProfilePayload: Encodable {
            let auth_provider: String
            let provider_avatar_url: String?
            let provider_full_name: String?
            let full_name: String?
        }

        let shouldSeedFullName = existingProfile.fullName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true

        try await client
            .from("profiles")
            .update(
                OAuthProfilePayload(
                    auth_provider: provider.rawValue,
                    provider_avatar_url: avatarURL,
                    provider_full_name: fullName,
                    full_name: shouldSeedFullName ? fullName : nil
                )
            )
            .eq("id", value: user.id)
            .execute()
    }

    private func mergedIdentityMetadata(from user: Auth.User) -> [String: AnyJSON] {
        var merged = user.userMetadata

        for identity in user.identities ?? [] {
            for (key, value) in identity.identityData ?? [:] {
                if merged[key] == nil {
                    merged[key] = value
                }
            }
        }

        return merged
    }

    private func preferredOAuthFullName(from user: Auth.User, identity: [String: AnyJSON]) -> String? {
        firstNonEmptyValue(
            user.userMetadata["full_name"]?.stringValue,
            user.userMetadata["name"]?.stringValue,
            identity["full_name"]?.stringValue,
            identity["name"]?.stringValue
        )
    }

    private func preferredOAuthAvatarURL(from user: Auth.User, identity: [String: AnyJSON]) -> String? {
        firstNonEmptyValue(
            user.userMetadata["avatar_url"]?.stringValue,
            user.userMetadata["picture"]?.stringValue,
            identity["avatar_url"]?.stringValue,
            identity["picture"]?.stringValue
        )
    }

    private func firstNonEmptyValue(_ values: String?...) -> String? {
        values.first { value in
            guard let value else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } ?? nil
    }

    #if os(iOS)
    private func prepareJPEGUnderLimit(image: UIImage, maxBytes: Int, startingMaxDimension: CGFloat) -> Data? {
        var maxDimension = startingMaxDimension

        while maxDimension >= 320 {
            let resizedImage = resizedImage(image, maxDimension: maxDimension)
            if let jpegData = jpegDataUnderLimit(from: resizedImage, maxBytes: maxBytes) {
                return jpegData
            }
            maxDimension -= 128
        }

        return nil
    }

    private func resizedImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let largestSide = max(image.size.width, image.size.height)
        guard largestSide > maxDimension else { return image }

        let scale = maxDimension / largestSide
        let targetSize = CGSize(
            width: floor(image.size.width * scale),
            height: floor(image.size.height * scale)
        )

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private func jpegDataUnderLimit(from image: UIImage, maxBytes: Int) -> Data? {
        var quality: CGFloat = 0.9

        while quality >= 0.25 {
            if let data = image.jpegData(compressionQuality: quality), data.count <= maxBytes {
                return data
            }
            quality -= 0.08
        }

        return nil
    }
    #elseif os(macOS)
    private func prepareJPEGUnderLimit(image: NSImage, maxBytes: Int, startingMaxDimension: CGFloat) -> Data? {
        var maxDimension = startingMaxDimension

        while maxDimension >= 320 {
            let resizedImage = resizedImage(image, maxDimension: maxDimension)
            if let jpegData = jpegDataUnderLimit(from: resizedImage, maxBytes: maxBytes) {
                return jpegData
            }
            maxDimension -= 128
        }

        return nil
    }

    private func resizedImage(_ image: NSImage, maxDimension: CGFloat) -> NSImage {
        let imageSize = image.size
        let largestSide = max(imageSize.width, imageSize.height)
        guard largestSide > maxDimension else { return image }

        let scale = maxDimension / largestSide
        let targetSize = NSSize(
            width: floor(imageSize.width * scale),
            height: floor(imageSize.height * scale)
        )

        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: targetSize))
        resized.unlockFocus()
        return resized
    }

    private func jpegDataUnderLimit(from image: NSImage, maxBytes: Int) -> Data? {
        guard
            let tiffData = image.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiffData)
        else {
            return nil
        }

        var quality: CGFloat = 0.9

        while quality >= 0.25 {
            if let data = rep.representation(using: .jpeg, properties: [.compressionFactor: quality]),
               data.count <= maxBytes {
                return data
            }
            quality -= 0.08
        }

        return nil
    }
    #endif
}

private extension SocialAuthProvider {
    var rawValue: String {
        switch self {
        case .google:
            return "google"
        case .apple:
            return "apple"
        }
    }

    var supabaseProvider: Provider {
        switch self {
        case .google:
            return .google
        case .apple:
            return .apple
        }
    }
}

// Simple Error Enum
enum AuthError: LocalizedError {
    case notAuthenticated
    case avatarTooLarge
    case oauthInvalidRedirectConfiguration
    case oauthMissingCallbackURL
    case oauthSessionStartFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return String(localized: "auth.error.notAuthenticated")
        case .avatarTooLarge:
            return String(localized: "auth.error.avatarTooLarge")
        case .oauthInvalidRedirectConfiguration:
            return String(localized: "auth.error.oauthInvalidRedirectConfiguration")
        case .oauthMissingCallbackURL:
            return String(localized: "auth.error.oauthMissingCallbackURL")
        case .oauthSessionStartFailed:
            return String(localized: "auth.error.oauthSessionStartFailed")
        }
    }
}
