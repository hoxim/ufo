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
    
    func signIn(email: String, password: String) async throws
    func signUp(email: String, password: String) async throws
    func completeProfile(fullName: String, avatarUrl: String?) async throws
    func signOut() async throws
}
