//
//  AuthMock.swift
//  ufo
//
//  Created by Marcin Ryzko on 29/01/2026.
//

import Foundation
import SwiftData
import Supabase

@MainActor
struct AuthMock {
    static func makeRepository(isLoggedIn: Bool = false) -> AuthRepository {

        let schema = Schema([
            UserProfile.self,
            Space.self,
            SpaceMembership.self,
            SpaceInvitation.self,
            Mission.self
        ])

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let repo = AuthRepository(client: SupabaseConfig.client)

        if isLoggedIn {
            let mockProfile = UserProfile(
                id: UUID(),
                email: "marcin@hoxim.com",
                fullName: "Commander Marcin",
                role: "admin"
            )

            container.mainContext.insert(mockProfile)
            
            repo.currentUser = mockProfile
            repo.isLoggedIn = true
        } else {
            repo.currentUser = nil
            repo.isLoggedIn = false
        }
        
        return repo
    }
}
