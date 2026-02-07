//
//  ufoApp.swift
//  ufo
//
//  Created by Marcin Ryzko on 29/01/2026.
//

import SwiftUI
import SwiftData

@main
struct UFOApp: App {
    // 1. Updated Schema (No UserEntity, using UserProfile)
    let container: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            Group.self,
            GroupMembership.self,
            GroupInvitation.self,
            Mission.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [config])
    }()
    
    @State private var authRepository: AuthRepository
    @State private var groupRepository: GroupRepository

    init() {
        let client = SupabaseConfig.client
        // 2. Repositories no longer need modelContext in init
        let authRepo = AuthRepository(client: client)
        let groupRepo = GroupRepository(client: client)
        
        _authRepository = State(initialValue: authRepo)
        _groupRepository = State(initialValue: groupRepo)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authRepository)
                .environment(groupRepository)
        }
        .modelContainer(container)
    }
}
