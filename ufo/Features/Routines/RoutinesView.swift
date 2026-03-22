import SwiftUI
import SwiftData

struct RoutinesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo

    @State private var selectedDate = Date()
    @State private var selectedRange: RoutineRange = .day
    @State private var routines: [Routine] = []
    @State private var routineLogs: [RoutineLog] = []
    @State private var showingCreator = false
    @State private var searchText = ""

    private var calendar: Calendar { .current }

    var body: some View {
        Group {
            if let selectedSpace = spaceRepo.selectedSpace {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header(for: selectedDate)

                        Picker("Zakres", selection: $selectedRange) {
                            ForEach(RoutineRange.allCases) { range in
                                Text(range.title).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)

                        switch selectedRange {
                        case .day:
                            RoutineDayTimeline(
                                date: selectedDate,
                                routines: routinesForSelectedDay,
                                logs: logsForSelectedDay,
                                onAdd: { showingCreator = true },
                                onLogRoutine: { routine in
                                    logRoutine(routine, on: selectedDate)
                                }
                            )
                        case .week:
                            RoutineWeekView(
                                startDate: startOfWeek(for: selectedDate),
                                routines: filteredRoutines,
                                logs: routineLogs
                            )
                        case .month:
                            RoutineMonthView(
                                monthDate: selectedDate,
                                routines: filteredRoutines,
                                logs: routineLogs
                            )
                        }
                    }
                    .padding()
                }
                .navigationTitle("Routines")
                .toolbar(.hidden, for: .tabBar)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            moveDate(by: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                        }

                        Button {
                            moveDate(by: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                        }

                        Button {
                            showingCreator = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingCreator) {
                    NavigationStack {
                        RoutineEditorView(spaceId: selectedSpace.id, actorId: authRepo.currentUser?.id) {
                            loadData()
                        }
                    }
                }
                .task {
                    loadData()
                }
                .onChange(of: spaceRepo.selectedSpace?.id) { _, _ in
                    loadData()
                }
                .safeAreaInset(edge: .bottom) {
                    FeatureBottomSearchBar(text: $searchText, prompt: "Search routines")
                }
            } else {
                ContentUnavailableView(
                    "Wybierz grupę",
                    systemImage: "person.3.sequence",
                    description: Text("Najpierw wybierz grupę, żeby zobaczyć plan routines.")
                )
            }
        }
    }

    private func header(for date: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(date.formatted(.dateTime.day().month(.wide).year()))
                .font(.largeTitle.bold())
            Text(date.formatted(.dateTime.weekday(.wide)))
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var routinesForSelectedDay: [Routine] {
        filteredRoutines
            .filter { $0.isActive(on: selectedDate, calendar: calendar) }
            .sorted { $0.startMinuteOfDay < $1.startMinuteOfDay }
    }

    private var filteredRoutines: [Routine] {
        let query = normalizedSearchQuery
        guard !query.isEmpty else { return routines }

        return routines.filter { routine in
            routine.title.localizedCaseInsensitiveContains(query)
                || routine.category.localizedCaseInsensitiveContains(query)
                || (routine.personName?.localizedCaseInsensitiveContains(query) ?? false)
                || (routine.notes?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private var normalizedSearchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var logsForSelectedDay: [RoutineLog] {
        routineLogs.filter { calendar.isDate($0.loggedAt, inSameDayAs: selectedDate) }
    }

    private func loadData() {
        guard let spaceId = spaceRepo.selectedSpace?.id else {
            routines = []
            routineLogs = []
            return
        }

        do {
            routines = try modelContext.fetch(
                FetchDescriptor<Routine>(
                    predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                    sortBy: [SortDescriptor(\.startMinuteOfDay, order: .forward)]
                )
            )

            routineLogs = try modelContext.fetch(
                FetchDescriptor<RoutineLog>(
                    predicate: #Predicate { $0.spaceId == spaceId },
                    sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
                )
            )
        } catch {
            routines = []
            routineLogs = []
            Log.dbError("RoutinesView.loadData", error)
        }
    }

    private func logRoutine(_ routine: Routine, on date: Date) {
        guard let spaceId = spaceRepo.selectedSpace?.id else { return }

        let log = RoutineLog(
            routineId: routine.id,
            spaceId: spaceId,
            loggedAt: defaultLogDate(for: routine, on: date),
            createdBy: authRepo.currentUser?.id
        )

        modelContext.insert(log)

        do {
            try modelContext.save()
            notifyHomeWidgetsDataDidChange()
            loadData()
        } catch {
            Log.dbError("RoutinesView.logRoutine", error)
        }
    }

    private func defaultLogDate(for routine: Routine, on date: Date) -> Date {
        if calendar.isDateInToday(date) {
            return .now
        }

        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .minute, value: routine.startMinuteOfDay, to: startOfDay) ?? startOfDay
    }

    private func moveDate(by value: Int) {
        switch selectedRange {
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: value, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .day, value: value * 7, to: selectedDate) ?? selectedDate
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: value, to: selectedDate) ?? selectedDate
        }
    }

    private func startOfWeek(for date: Date) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }
}

#Preview("Routines") {
    let schema = Schema([
        UserProfile.self,
        Space.self,
        SpaceMembership.self,
        Routine.self,
        RoutineLog.self
    ])
    let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext

    let user = UserProfile(id: UUID(), email: "preview@ufo.app", fullName: "Preview User", role: "admin")
    let space = Space(id: UUID(), name: "Family Crew", inviteCode: "UFO123")
    let membership = SpaceMembership(user: user, space: space, role: "admin")
    let todayWeekday = Calendar.current.component(.weekday, from: .now)

    context.insert(user)
    context.insert(space)
    context.insert(membership)

    let breakfast = Routine(spaceId: space.id, title: "Śniadanie", category: RoutineCategory.food.rawValue, personName: "Leo", startMinuteOfDay: 450, durationMinutes: 30, activeWeekdays: [todayWeekday], createdBy: user.id)
    let nap = Routine(spaceId: space.id, title: "Drzemka", category: RoutineCategory.sleep.rawValue, personName: "Leo", startMinuteOfDay: 780, durationMinutes: 75, activeWeekdays: [todayWeekday], createdBy: user.id)
    let training = Routine(spaceId: space.id, title: "Trening", category: RoutineCategory.training.rawValue, personName: "Mama", startMinuteOfDay: 1080, durationMinutes: 60, activeWeekdays: [todayWeekday], createdBy: user.id)

    context.insert(breakfast)
    context.insert(nap)
    context.insert(training)
    context.insert(RoutineLog(routineId: breakfast.id, spaceId: space.id, loggedAt: .now.addingTimeInterval(-60 * 60), createdBy: user.id))
    context.insert(RoutineLog(routineId: nap.id, spaceId: space.id, loggedAt: .now.addingTimeInterval(-20 * 60), createdBy: user.id))
    try! context.save()

    let authRepo = AuthRepository(client: SupabaseConfig.client, isLoggedIn: true, currentUser: user)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    spaceRepo.selectedSpace = space

    return NavigationStack {
        RoutinesView()
    }
    .environment(authRepo)
    .environment(spaceRepo)
    .modelContainer(container)
}
