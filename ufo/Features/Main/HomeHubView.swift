import SwiftUI
import SwiftData
import Charts

struct HomeHubView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AuthStore.self) private var authStore
    @Environment(SpaceRepository.self) private var spaceRepository
    @Environment(AppNotificationStore.self) private var notificationStore
    @Environment(AppPreferences.self) private var appPreferences

    @State private var showProfileSheet = false
    @State private var showCustomizeSheet = false
    @State private var widget = HomeWidgetState()
    @State private var budgetRange: BudgetWidgetRange = .month
    @State private var activeRoute: HomeRoute?

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack {
                    Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.secondary.opacity(0.08), in: Capsule())

                    Spacer()

                    Button {
                        showCustomizeSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.subheadline.weight(.semibold))

                            Text("Edit Home")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.thinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Customize Home")
                }

                ForEach(widgetRows) { row in
                    switch row.style {
                    case .single:
                        HStack(spacing: 0) {
                            if let widget = row.widgets.first {
                                homeWidgetView(widget)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    case .pair:
                        HStack(spacing: 12) {
                            if let first = row.widgets.first {
                                homeWidgetView(first)
                            }

                            if row.widgets.count > 1, let second = row.widgets.last {
                                homeWidgetView(second)
                            } else {
                                HomeMetricCardPlaceholder()
                            }
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 28)
        }
        .appScreenBackground()
        #if os(iOS)
        .navigationTitle("")
        #else
        .navigationTitle("Home")
#endif
        .navigationDestination(item: $activeRoute) { route in
            destination(for: route)
        }
        .toolbar {
            #if !os(macOS)
            ToolbarItem(placement: homeSpaceToolbarPlacement) {
                spaceSwitcher
            }
            #endif

            ToolbarItem(placement: profileToolbarPlacement) {
                Button {
                    open(.notifications)
                } label: {
                    NotificationBellButton(unreadCount: notificationStore.unreadCount)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open inbox")
            }

            #if !os(macOS)
            ToolbarItem(placement: profileToolbarPlacement) {
                Button {
                    showProfileSheet = true
                } label: {
                    AvatarCircle(user: authStore.currentUser)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("home.hub.profile.open")
            }
            #endif
        }
        .task {
            refreshWidgets()
        }
        .onAppear {
            refreshWidgets()
        }
        .onChange(of: spaceRepository.selectedSpace?.id) { _, _ in
            refreshWidgets()
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .active {
                refreshWidgets()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .homeWidgetsDataDidChange)) { _ in
            refreshWidgets()
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfileHubView()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showCustomizeSheet) {
            HomeCustomizationView()
                .environment(appPreferences)
                .presentationDetents([.medium, .large])
        }
    }

    private func open(_ route: HomeRoute) {
        activeRoute = route
    }

    @ViewBuilder
    private func destination(for route: HomeRoute) -> some View {
        switch route {
        case .missions:
            MissionsListView()
        case .lists:
            SharedListsView()
        case .notes:
            NotesView()
        case .incidents:
            IncidentsListView()
        case .notifications:
            NotificationCenterView()
        case .locations:
            LocationsView()
        case .routines:
            RoutinesView()
        case .budget:
            BudgetView()
        case .quickAddMission:
            MissionsListView(autoPresentAdd: true)
        case .quickAddNote:
            NotesView(autoPresentAdd: true)
        case .quickAddIncident:
            IncidentsListView(autoPresentAdd: true)
        case .quickAddList:
            SharedListsView(autoPresentAdd: true)
        case .quickAddBudgetEntry:
            BudgetView(autoPresentAddEntry: true)
        }
    }

    /// Refreshes Home widgets using local data from current selected space.
    private func refreshWidgets() {
        guard let spaceId = spaceRepository.selectedSpace?.id else {
            widget = HomeWidgetState()
            return
        }
        do {
            let missions = try modelContext.fetch(
                FetchDescriptor<Mission>(
                    predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil && $0.isCompleted == false },
                    sortBy: [SortDescriptor(\.dueDate, order: .forward), SortDescriptor(\.createdAt, order: .forward)]
                )
            )

            let lists = try modelContext.fetch(
                FetchDescriptor<SharedList>(
                    predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil }
                )
            )

            let notes = try modelContext.fetch(
                FetchDescriptor<Note>(
                    predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil }
                )
            )

            let allIncidents = try modelContext.fetch(
                FetchDescriptor<Incident>(
                    predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                    sortBy: [SortDescriptor(\.occurrenceDate, order: .forward)]
                )
            )
            let nearestIncident = allIncidents.first(where: { $0.occurrenceDate >= Date.now })

            let savedPlaces = try modelContext.fetch(
                FetchDescriptor<SavedPlace>(
                    predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil }
                )
            )

            let checkIns = try modelContext.fetch(
                FetchDescriptor<LocationCheckIn>(
                    predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                    sortBy: [SortDescriptor(\.checkedInAt, order: .reverse)]
                )
            )

            let routines = try modelContext.fetch(
                FetchDescriptor<Routine>(
                    predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                    sortBy: [SortDescriptor(\.startMinuteOfDay, order: .forward)]
                )
            )
            let todayWeekday = Calendar.current.component(.weekday, from: .now)
            let todayRoutines = routines.filter { $0.activeWeekdays.contains(todayWeekday) }
            let currentMinute = Calendar.current.component(.hour, from: .now) * 60 + Calendar.current.component(.minute, from: .now)
            let nextRoutine = todayRoutines.first(where: { $0.startMinuteOfDay >= currentMinute }) ?? todayRoutines.first
            let routineLogs = try modelContext.fetch(
                FetchDescriptor<RoutineLog>(
                    predicate: #Predicate { $0.spaceId == spaceId },
                    sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
                )
            )
            let completedTodayRoutineIds = Set(
                routineLogs
                    .filter { Calendar.current.isDateInToday($0.loggedAt) }
                    .map(\.routineId)
            )

            let budgetEntries = try modelContext.fetch(
                FetchDescriptor<BudgetEntry>(
                    predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                    sortBy: [SortDescriptor(\.entryDate, order: .forward)]
                )
            )

            widget = HomeWidgetState(
                nextMissionTitle: missions.first?.title,
                activeListsCount: lists.count,
                notesCount: notes.count,
                nearestIncidentTitle: nearestIncident?.title,
                nearestIncidentDateText: nearestIncident?.occurrenceDate.formatted(date: .abbreviated, time: .shortened),
                dueTodayCount: missions.filter {
                    guard let dueDate = $0.dueDate else { return false }
                    return Calendar.current.isDateInToday(dueDate)
                }.count,
                recurringMissionCount: missions.filter(\.isRecurringValue).count,
                pinnedNotesCount: notes.filter(\.isPinnedValue).count,
                openIncidentsCount: allIncidents.filter { $0.resolvedStatus != IncidentStatus.resolved.rawValue }.count,
                criticalIncidentsCount: allIncidents.filter { $0.resolvedSeverity == IncidentSeverity.critical.rawValue }.count,
                savedPlacesCount: savedPlaces.count,
                recentCheckInText: checkIns.first.map { "\($0.userDisplayName) · \($0.placeName ?? "Current")" },
                routinesCount: todayRoutines.count,
                completedTodayRoutinesCount: completedTodayRoutineIds.count,
                nextRoutineText: nextRoutine.map { "\($0.title) · \(String(format: "%02d:%02d", $0.startMinuteOfDay / 60, $0.startMinuteOfDay % 60))" },
                budgetEntries: budgetEntries
            )
        } catch {
            Log.dbError("HomeHub.refreshWidgets (SwiftData fetch)", error)
            widget = HomeWidgetState()
        }
    }

    private var profileToolbarPlacement: ToolbarItemPlacement {
#if os(macOS)
        .automatic
#else
        .topBarTrailing
#endif
    }

    private var homeSpaceToolbarPlacement: ToolbarItemPlacement {
#if os(macOS)
        .navigation
#else
        .topBarLeading
#endif
    }

    private var visibleWidgetPreferences: [HomeWidgetPreference] {
        appPreferences.homeWidgets.filter(\.isVisible)
    }

    var visibleWidgetKinds: Set<HomeWidgetKind> {
        Set(visibleWidgetPreferences.map(\.kind))
    }

    private var widgetRows: [HomeWidgetRow] {
        var rows: [HomeWidgetRow] = []
        var halfRow: [HomeWidgetPreference] = []

        for widgetPreference in visibleWidgetPreferences {
            if widgetPreference.span == .full {
                if !halfRow.isEmpty {
                    rows.append(HomeWidgetRow(style: .pair, widgets: halfRow))
                    halfRow.removeAll()
                }
                rows.append(HomeWidgetRow(style: .single, widgets: [widgetPreference]))
            } else {
                halfRow.append(widgetPreference)
                if halfRow.count == 2 {
                    rows.append(HomeWidgetRow(style: .pair, widgets: halfRow))
                    halfRow.removeAll()
                }
            }
        }

        if !halfRow.isEmpty {
            rows.append(HomeWidgetRow(style: .pair, widgets: halfRow))
        }

        return rows
    }

    @ViewBuilder
    private func homeWidgetView(_ preference: HomeWidgetPreference) -> some View {
        switch preference.kind {
        case .missions:
            metricWidgetButton(route: .missions) {
                HomeMetricCard(
                    sectionTitle: String(localized: "home.hub.shortcut.missions.title"),
                    sectionIcon: "target",
                    title: String(localized: "home.hub.widget.nextMission.title"),
                    value: widget.nextMissionTitle ?? String(localized: "home.hub.widget.nextMission.empty"),
                    subtitle: widget.nextMissionTitle == nil
                        ? String(localized: "home.hub.widget.nextMission.subtitleEmpty")
                        : String(localized: "home.hub.widget.nextMission.subtitle"),
                    tint: .orange,
                    span: preference.span
                )
            }
        case .lists:
            metricWidgetButton(route: .lists) {
                HomeMetricCard(
                    sectionTitle: String(localized: "home.hub.shortcut.lists.title"),
                    sectionIcon: "checklist",
                    title: String(localized: "home.hub.widget.activeLists.title"),
                    value: "\(widget.activeListsCount)",
                    subtitle: String(localized: "home.hub.widget.activeLists.subtitle"),
                    tint: .pink,
                    span: preference.span
                )
            }
        case .notes:
            metricWidgetButton(route: .notes) {
                HomeMetricCard(
                    sectionTitle: String(localized: "home.hub.shortcut.notes.title"),
                    sectionIcon: "note.text",
                    title: String(localized: "home.hub.widget.notes.title"),
                    value: "\(widget.notesCount)",
                    subtitle: String(localized: "home.hub.widget.notes.subtitle"),
                    tint: .blue,
                    span: preference.span
                )
            }
        case .incidents:
            metricWidgetButton(route: .incidents) {
                HomeMetricCard(
                    sectionTitle: String(localized: "home.hub.shortcut.incidents.title"),
                    sectionIcon: "bolt.horizontal",
                    title: String(localized: "home.hub.widget.nearestIncident.title"),
                    value: widget.nearestIncidentTitle ?? String(localized: "home.hub.widget.nearestIncident.empty"),
                    subtitle: widget.nearestIncidentDateText ?? String(localized: "home.hub.widget.nearestIncident.subtitle"),
                    tint: .red,
                    span: preference.span
                )
            }
        case .routines:
            metricWidgetButton(route: .routines) {
                HomeMetricCard(
                    sectionTitle: "Routines",
                    sectionIcon: "clock.arrow.circlepath",
                    title: "Plan today",
                    value: widget.routinesProgressText,
                    subtitle: widget.nextRoutineText ?? "No routines scheduled",
                    tint: .green,
                    span: preference.span
                )
            }
        case .summary:
            TodaySummaryCard(widget: widget)
        case .budget:
            HomeBudgetCard(
                entries: widget.budgetEntries,
                range: $budgetRange,
                onOpen: { open(.budget) }
            )
        }
    }

    private func metricWidgetButton<Label: View>(route: HomeRoute, @ViewBuilder label: () -> Label) -> some View {
        Button {
            open(route)
        } label: {
            label()
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var spaceSwitcher: some View {
        let memberships = authStore.currentUser?.memberships ?? []

        if !memberships.isEmpty {
            Menu {
                ForEach(memberships) { membership in
                    if let space = membership.space {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                spaceRepository.selectedSpace = space
                            }
                            refreshWidgets()
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(space.name)
                                    Text(space.type.displayName)
                                        .font(.caption)
                                }
                            } icon: {
                                Image(systemName: spaceRepository.selectedSpace?.id == space.id ? "checkmark.circle.fill" : "circle")
                            }
                        }
                    }
                }
            } label: {
                if let selectedSpace = spaceRepository.selectedSpace {
                    ActiveSpaceMenuButton(space: selectedSpace)
                } else {
                    Image(systemName: "person.3.fill")
                        .font(.headline)
                }
            }
            .accessibilityLabel("Zmień aktywną grupę")
        }
    }
}

#Preview("Home Hub") {
    let schema = Schema([
        AppNotification.self,
        UserProfile.self,
        Space.self,
        SpaceMembership.self,
        Mission.self,
        SharedList.self,
        Note.self,
        BudgetEntry.self,
        Incident.self,
        SavedPlace.self,
        LocationCheckIn.self,
        Routine.self,
        RoutineLog.self
    ])
    let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext

    let user = UserProfile(id: UUID(), email: "preview@ufo.app", fullName: "Preview User", role: "admin")
    let space = Space(id: UUID(), name: "Family Crew", inviteCode: "UFO123")
    context.insert(user)
    context.insert(space)
    context.insert(SpaceMembership(user: user, space: space, role: "admin"))
    let mission = Mission(spaceId: space.id, title: "Buy food", missionDescription: "Weekly shopping", difficulty: 2)
    mission.dueDate = .now
    mission.isRecurring = true
    context.insert(mission)
    let note = Note(spaceId: space.id, title: "Reminder", content: "Take umbrella", createdBy: user.id)
    note.isPinned = true
    context.insert(SharedList(spaceId: space.id, name: "Shopping list", type: "shopping"))
    context.insert(note)
    let incident = Incident(spaceId: space.id, title: "Storm alert", severity: IncidentSeverity.critical.rawValue, status: IncidentStatus.open.rawValue, occurrenceDate: .now, createdBy: user.id)
    context.insert(incident)
    let savedPlace = SavedPlace(spaceId: space.id, name: "School", category: "Kids", latitude: 52.23, longitude: 21.01, createdBy: user.id)
    context.insert(savedPlace)
    context.insert(LocationCheckIn(spaceId: space.id, userId: user.id, userDisplayName: "Preview User", placeId: savedPlace.id, placeName: savedPlace.name, latitude: savedPlace.latitude, longitude: savedPlace.longitude))
    context.insert(BudgetEntry(spaceId: space.id, title: "Salary", kind: "income", amount: 4200, category: "Work"))
    context.insert(BudgetEntry(spaceId: space.id, title: "Groceries", kind: "expense", amount: 300, category: "Food"))
    let routine = Routine(spaceId: space.id, title: "Dinner", category: RoutineCategory.food.rawValue, startMinuteOfDay: 1080, durationMinutes: 45, createdBy: user.id)
    context.insert(routine)
    context.insert(RoutineLog(routineId: routine.id, spaceId: space.id, loggedAt: .now, createdBy: user.id))
    do {
        try context.save()
    } catch {
        Log.dbError("HomeHub preview context.save", error)
    }

    let authRepo = AuthRepository(client: SupabaseConfig.client, isLoggedIn: true, currentUser: user)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    spaceRepo.selectedSpace = space
    let authStore = AuthStore(authRepository: authRepo, spaceRepository: spaceRepo)
    authStore.state = .ready
    let notificationStore = AppNotificationStore(modelContext: context)
    let appPreferences = AppPreferences.shared

    return HomeHubView()
        .environment(authStore)
        .environment(spaceRepo)
        .environment(notificationStore)
        .environment(appPreferences)
        .modelContainer(container)
}
