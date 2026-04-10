#if os(iOS)

import SwiftUI
import SwiftData

struct PadRoutinesScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo

    @State private var selectedDate = Date()
    @State private var selectedRange: PadRoutineRange = .day
    @State private var routines: [Routine] = []
    @State private var routineLogs: [RoutineLog] = []
    @State private var showingCreator = false
    @State private var creatorToken = UUID()
    @State private var searchText = ""

    private var calendar: Calendar { .current }

    var body: some View {
        Group {
            if let selectedSpace = spaceRepo.selectedSpace {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header(for: selectedDate)

                        rangePicker

                        switch selectedRange {
                        case .day:
                            PadRoutineDayTimeline(
                                date: selectedDate,
                                routines: routinesForSelectedDay,
                                logs: logsForSelectedDay,
                                onAdd: { showingCreator = true },
                                onLogRoutine: { routine in
                                    logRoutine(routine, on: selectedDate)
                                }
                            )
                        case .week:
                            PadRoutineWeekView(
                                startDate: startOfWeek(for: selectedDate),
                                routines: filteredRoutines,
                                logs: routineLogs
                            )
                        case .month:
                            PadRoutineMonthView(
                                monthDate: selectedDate,
                                routines: filteredRoutines,
                                logs: routineLogs
                            )
                        }
                    }
                    .padding()
                }
                .appScreenBackground()
                .navigationTitle("navigation.item.routines")
                .navigationBarTitleDisplayMode(.large)
                .hideTabBarIfSupported()
                .toolbar {
                    ToolbarItemGroup(placement: .platformTopBarTrailing) {
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
                            creatorToken = UUID()
                            showingCreator = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .adaptiveFormPresentation(isPresented: $showingCreator) {
                    PadRoutineEditorView(spaceId: selectedSpace.id, actorId: authRepo.currentUser?.id) {
                        loadData()
                    }
                    .id(creatorToken)
                    .presentationDetents([.medium, .large])
                }
                .task {
                    loadData()
                }
                .onChange(of: spaceRepo.selectedSpace?.id) { _, _ in
                    loadData()
                }
                .safeAreaInset(edge: .bottom) {
                    FeatureBottomSearchBar(text: $searchText, prompt: "routines.search.prompt")
                }
            } else {
                ContentUnavailableView(
                    "spaces.selector.choose",
                    systemImage: "person.3.sequence",
                    description: Text("routines.empty.noSpace")
                )
            }
        }
        .appScreenBackground()
    }

    private func header(for date: Date) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("navigation.item.routines")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    if let selectedSpaceName = spaceRepo.selectedSpace?.name, !selectedSpaceName.isEmpty {
                        Text(selectedSpaceName)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Text(verbatim: "\(filteredRoutines.count)")
                        .foregroundStyle(.secondary)
                }
                .font(.footnote)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(date.formatted(.dateTime.day().month(.wide).year()))
                    .font(.largeTitle.bold())
                Text(date.formatted(.dateTime.weekday(.wide)))
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rangePicker: some View {
        HStack(spacing: 12) {
            Text("routines.range")
                .font(.headline)

            HStack(spacing: 6) {
                ForEach(PadRoutineRange.allCases) { range in
                    Button {
                        selectedRange = range
                    } label: {
                        Text(range.title)
                            .font(.headline.weight(selectedRange == range ? .semibold : .regular))
                            .foregroundStyle(selectedRange == range ? Color.white : .primary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(selectedRange == range ? Color.accentColor : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color.secondarySystemBackgroundAdaptive, in: Capsule(style: .continuous))
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
            Log.dbError("PadRoutinesScreen.loadData", error)
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
            Log.dbError("PadRoutinesScreen.logRoutine", error)
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
        PadRoutinesScreen()
    }
    .environment(authRepo)
    .environment(spaceRepo)
    .modelContainer(container)
}

#endif
