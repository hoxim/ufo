//
//  ufoApp.swift
//  ufo
//
//  Created by Marcin Ryzko on 29/01/2026.
//

import SwiftUI
import SwiftData
import Supabase
import Auth

@main
struct UFOApp: App {
    let container: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            Space.self,
            SpaceMembership.self,
            SpaceInvitation.self,
            Mission.self,
            Incident.self,
            LinkedThing.self,
            Assignment.self,
            BudgetEntry.self,
            BudgetGoal.self,
            SharedList.self,
            SharedListItem.self,
            LocationPing.self,
            SpaceMessage.self,
            Note.self,
            NoteFolder.self
        ])
        // New local store name to avoid loading an old incompatible SwiftData file.
        let config = ModelConfiguration("UFO_Clean_DB_v2", isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            assertionFailure("Failed to load SwiftData store: \(error)")
            let inMemoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [inMemoryConfig])
        }
    }()
    
    @State private var authRepository: AuthRepository
    @State private var spaceRepository: SpaceRepository
    @State private var authStore: AuthStore

    init() {
        let client = SupabaseConfig.client

        let authRepo = AuthRepository(client: client)
        let spaceRepo = SpaceRepository(client: client)
        let store = AuthStore(authRepository: authRepo, spaceRepository: spaceRepo)
        
        _authRepository = State(initialValue: authRepo)
        _spaceRepository = State(initialValue: spaceRepo)
        _authStore = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authRepository)
                .environment(spaceRepository)
                .environment(authStore)
                .background(Color.backgroundSolid)
                .onOpenURL { url in
                    SupabaseConfig.client.auth.handle(url)
                }
        }
        .modelContainer(container)
    }
}
