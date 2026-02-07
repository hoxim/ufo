//
//  AuthRepositoryProtocol.swift
//  ufo
//
//  Created by Marcin Ryzko on 30/01/2026.
//

import Foundation

import Foundation

protocol AuthRepositoryProtocol {
    /// The currently authenticated user's profile data.
    var currentUser: UserProfile? { get }
    
    /// Signs in an existing user using email and password.
    /// - Parameters:
    ///   - email: User's email address.
    ///   - password: User's password.
    func signIn(email: String, password: String) async throws
    
    /// Registers a new user with minimal information.
    /// Profile details like name or avatar should be set later via `completeProfile`.
    /// - Parameters:
    ///   - email: User's email address.
    ///   - password: User's password.
    func signUp(email: String, password: String) async throws
    
    /// Updates the user's profile information after the initial registration or when editing profile.
    /// - Parameters:
    ///   - fullName: The user's display name.
    ///   - avatarUrl: Optional URL to the user's avatar image.
    func completeProfile(fullName: String, avatarUrl: String?) async throws
    
    /// Signs out the current user and clears local session data.
    func signOut() async throws
}
