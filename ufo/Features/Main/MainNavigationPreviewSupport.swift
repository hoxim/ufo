import Foundation
import SwiftData

@MainActor
struct MainNavigationPreviewData {
    let container: ModelContainer
    let authRepository: AuthRepository
    let authStore: AuthStore
    let spaceRepository: SpaceRepository
    let notificationStore: AppNotificationStore
}

@MainActor
enum MainNavigationPreviewFactory {
    static func make() -> MainNavigationPreviewData {
        let schema = Schema([
            AppNotification.self,
            UserProfile.self,
            Space.self,
            SpaceMembership.self,
            Mission.self,
            SharedList.self,
            Note.self,
            BudgetEntry.self,
            Routine.self,
            RoutineLog.self
        ])
        let container = try! ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let user = UserProfile(
            id: UUID(),
            email: "preview@ufo.app",
            fullName: "Preview User",
            role: "admin"
        )
        let space = Space(id: UUID(), name: "Family Crew", inviteCode: "UFO123")
        let membership = SpaceMembership(user: user, space: space, role: "admin")
        user.memberships = [membership]

        context.insert(user)
        context.insert(space)
        context.insert(membership)
        context.insert(Mission(spaceId: space.id, title: "Buy food", missionDescription: "Weekly shopping", difficulty: 2))
        context.insert(SharedList(spaceId: space.id, name: "Shopping list", type: "shopping"))
        context.insert(Note(spaceId: space.id, title: "Reminder", content: "Take umbrella", createdBy: user.id))
        context.insert(BudgetEntry(spaceId: space.id, title: "Salary", kind: "income", amount: 4200, category: "Work"))
        let routine = Routine(spaceId: space.id, title: "Breakfast", category: RoutineCategory.food.rawValue, startMinuteOfDay: 480, durationMinutes: 30, createdBy: user.id)
        context.insert(routine)
        context.insert(RoutineLog(routineId: routine.id, spaceId: space.id, loggedAt: .now, createdBy: user.id))

        try? context.save()

        let authRepository = AuthRepository(
            client: SupabaseConfig.client,
            isLoggedIn: true,
            currentUser: user
        )
        let spaceRepository = SpaceRepository(client: SupabaseConfig.client)
        spaceRepository.selectedSpace = space

        let authStore = AuthStore(authRepository: authRepository, spaceRepository: spaceRepository)
        authStore.state = .ready
        let notificationStore = AppNotificationStore(modelContext: context)

        return MainNavigationPreviewData(
            container: container,
            authRepository: authRepository,
            authStore: authStore,
            spaceRepository: spaceRepository,
            notificationStore: notificationStore
        )
    }
}
