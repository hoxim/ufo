//
//  AuthRepositoryProtocol.swift
//  ufo
//
//  Created by Marcin Ryzko on 30/01/2026.
//

import Foundation

import Foundation

protocol AuthRepositoryProtocol {

    var currentUser: UserProfile? { get }
    
    /// Handles sign in.
    func signIn(email: String, password: String) async throws
    /// Handles sign up.
    func signUp(email: String, password: String) async throws
    /// Handles complete profile.
    func completeProfile(fullName: String, avatarUrl: String?) async throws
    /// Handles sign out.
    func signOut() async throws
}
