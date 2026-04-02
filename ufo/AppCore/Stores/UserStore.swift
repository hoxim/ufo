//
//  UserStore.swift
//  ufo
//
//  Created by Marcin Ryzko on 22/02/2026.
//

import SwiftUI
import Observation

@Observable
final class UserStore {
    var currentUser: UserProfile?

    private let authRepository: AuthRepository

    init(authRepository: AuthRepository) {
        self.authRepository = authRepository
        self.currentUser = authRepository.currentUser
    }

    @MainActor
    /// Handles refresh user.
    func refreshUser() async {
        // Fetch latest data form Supabase and update local
        guard let userId = authRepository.currentUser?.id else { return }
        do {
            try await authRepository.fetchUserProfile(id: userId)
            // update store
            self.currentUser = authRepository.currentUser
        } catch {
            // fallback to local data
            self.currentUser = authRepository.currentUser
            Log.dbError("profiles.refresh (UserStore)", error)
        }
    }
}
