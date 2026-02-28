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
    let container: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            Space.self,
            SpaceMembership.self,
            SpaceInvitation.self,
            Mission.self
        ])
        let config = ModelConfiguration("UFO_Clean_DB", isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [config])
    }()
    
    @State private var authRepository: AuthRepository
    @State private var spaceRepository: SpaceRepository

    init() {
        let client = SupabaseConfig.client

        let authRepo = AuthRepository(client: client)
        let spaceRepo = SpaceRepository(client: client)
        
        _authRepository = State(initialValue: authRepo)
        _spaceRepository = State(initialValue: spaceRepo)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authRepository)
                .environment(spaceRepository)
                .background(Color.backgroundSolid)
        }
        .modelContainer(container)
    }
}
