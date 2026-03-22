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
            AppNotification.self,
            UserSettings.self,
            UserProfile.self,
            Space.self,
            SpaceMembership.self,
            SpaceRoleDefinition.self,
            SpaceAccessRole.self,
            SpaceVisibilityGroup.self,
            SpaceVisibilityGroupMember.self,
            SpaceInvitation.self,
            Mission.self,
            MissionVisibilityGroup.self,
            Incident.self,
            LinkedThing.self,
            Assignment.self,
            BudgetEntry.self,
            BudgetGoal.self,
            SharedList.self,
            SharedListItem.self,
            LocationPing.self,
            SavedPlace.self,
            LocationCheckIn.self,
            SpaceMessage.self,
            Note.self,
            NoteFolder.self,
            Routine.self,
            RoutineLog.self
        ])
        // New local store name to avoid loading an old incompatible SwiftData file.
        let config = ModelConfiguration("UFO_Clean_DB_v6", isStoredInMemoryOnly: false)

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
    @State private var notificationStore: AppNotificationStore
    @State private var appPreferences: AppPreferences

    init() {
        let client = SupabaseConfig.client

        let authRepo = AuthRepository(client: client)
        let spaceRepo = SpaceRepository(client: client)
        let store = AuthStore(authRepository: authRepo, spaceRepository: spaceRepo)
        let notificationStore = AppNotificationStore(modelContext: container.mainContext)
        let appPreferences = AppPreferences.shared
        
        _authRepository = State(initialValue: authRepo)
        _spaceRepository = State(initialValue: spaceRepo)
        _authStore = State(initialValue: store)
        _notificationStore = State(initialValue: notificationStore)
        _appPreferences = State(initialValue: appPreferences)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authRepository)
                .environment(spaceRepository)
                .environment(authStore)
                .environment(notificationStore)
                .environment(appPreferences)
                .background(Color.backgroundSolid)
                .onOpenURL { url in
                    SupabaseConfig.client.auth.handle(url)
                }
        }
        .modelContainer(container)
    }
}
