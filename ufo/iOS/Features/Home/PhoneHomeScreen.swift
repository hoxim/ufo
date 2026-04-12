#if os(iOS)

import SwiftUI
import SwiftData

struct PhoneHomeScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AuthStore.self) private var authStore
    @Environment(SpaceRepository.self) private var spaceRepository
    @Environment(AppNotificationStore.self) private var notificationStore
    @Environment(AppPreferences.self) private var appPreferences

    @State private var showProfileSheet = false
    @State private var showCustomizeSheet = false
    @State private var widget = PhoneHomeWidgetState()
    @State private var budgetRange: PhoneBudgetWidgetRange = .month
    @State private var activeRoute: PhoneHomeRoute?

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack {
                    Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(AppTheme.Colors.mutedFill, in: Capsule())

                    Spacer()

                    Button {
                        showCustomizeSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.subheadline.weight(.semibold))

                            Text("home.screen.action.edit")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(AppTheme.Colors.card, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("home.screen.accessibility.customize")
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
                                PhoneHomeMetricCardPlaceholder()
                            }
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 28)
        }
        .appScreenBackground()
        .navigationTitle("")
        .navigationDestination(item: $activeRoute) { route in
            destination(for: route)
        }
        .toolbar {
            ToolbarItem(placement: .platformTopBarLeading) {
                spaceSwitcher
            }

            ToolbarItem(placement: .platformTopBarTrailing) {
                Button {
                    open(.notifications)
                } label: {
                    PhoneNotificationBellButton(unreadCount: notificationStore.unreadCount)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("home.screen.accessibility.notifications")
            }

            ToolbarItem(placement: .platformTopBarTrailing) {
                Button {
                    showProfileSheet = true
                } label: {
                    AvatarCircle(user: authStore.currentUser)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("home.hub.profile.open")
            }
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
            PhoneProfileScreen()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showCustomizeSheet) {
            PhoneHomeCustomizationView(keepsEditModeActive: true)
                .environment(appPreferences)
                .presentationDetents([.medium, .large])
        }
    }

    private func open(_ route: PhoneHomeRoute) {
        activeRoute = route
    }

    @ViewBuilder
    private func destination(for route: PhoneHomeRoute) -> some View {
        switch route {
        case .missions:
            PhoneMissionsScreen()
        case .lists:
            PhoneListsScreen()
        case .notes:
            PhoneNotesScreen()
        case .incidents:
            PhoneIncidentsScreen()
        case .notifications:
            PhoneNotificationCenterScreen()
        case .locations:
            PhoneLocationsScreen()
        case .routines:
            PhoneRoutinesScreen()
        case .budget:
            PhoneBudgetScreen()
        case .quickAddMission:
            PhoneMissionsScreen(autoPresentAdd: true)
        case .quickAddNote:
            PhoneNotesScreen(autoPresentAdd: true)
        case .quickAddIncident:
            PhoneIncidentsScreen(autoPresentAdd: true)
        case .quickAddList:
            PhoneListsScreen(autoPresentAdd: true)
        case .quickAddBudgetEntry:
            PhoneBudgetScreen(autoPresentAddEntry: true)
        }
    }

    private func refreshWidgets() {
        guard let spaceId = spaceRepository.selectedSpace?.id else {
            widget = PhoneHomeWidgetState()
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

            widget = PhoneHomeWidgetState(
                nextMissionTitle: missions.first?.title,
                activeListsCount: lists.count,
                notesCount: notes.count,
                nearestIncidentTitle: nearestIncident?.title,
                nearestIncidentDateText: nearestIncident?.occurrenceDate.formatted(date: .abbreviated, time: .shortened),
                dueTodayCount: missions.filter {
                    guard let dueDate = $0.dueDate else { return false }
                    return Calendar.current.isDateInToday(dueDate)
                }.count,
                recurringMissionCount: missions.filter(\.isRecurring).count,
                pinnedNotesCount: notes.filter(\.isPinnedValue).count,
                openIncidentsCount: allIncidents.filter { $0.status != .resolved }.count,
                criticalIncidentsCount: allIncidents.filter { $0.severity == .critical }.count,
                savedPlacesCount: savedPlaces.count,
                recentCheckInText: checkIns.first.map { "\($0.userDisplayName) · \($0.placeName ?? String(localized: "home.location.current"))" },
                routinesCount: todayRoutines.count,
                completedTodayRoutinesCount: completedTodayRoutineIds.count,
                nextRoutineText: nextRoutine.map { "\($0.title) · \(String(format: "%02d:%02d", $0.startMinuteOfDay / 60, $0.startMinuteOfDay % 60))" },
                budgetEntries: budgetEntries
            )
        } catch {
            Log.dbError("PhoneHomeScreen.refreshWidgets (SwiftData fetch)", error)
            widget = PhoneHomeWidgetState()
        }
    }

    private var visibleWidgetPreferences: [HomeWidgetPreference] {
        appPreferences.homeWidgets.filter(\.isVisible)
    }

    private var widgetRows: [PhoneHomeWidgetRow] {
        var rows: [PhoneHomeWidgetRow] = []
        var halfRow: [HomeWidgetPreference] = []

        for widgetPreference in visibleWidgetPreferences {
            if widgetPreference.span == .full {
                if !halfRow.isEmpty {
                    rows.append(PhoneHomeWidgetRow(style: .pair, widgets: halfRow))
                    halfRow.removeAll()
                }
                rows.append(PhoneHomeWidgetRow(style: .single, widgets: [widgetPreference]))
            } else {
                halfRow.append(widgetPreference)
                if halfRow.count == 2 {
                    rows.append(PhoneHomeWidgetRow(style: .pair, widgets: halfRow))
                    halfRow.removeAll()
                }
            }
        }

        if !halfRow.isEmpty {
            rows.append(PhoneHomeWidgetRow(style: .pair, widgets: halfRow))
        }

        return rows
    }

    @ViewBuilder
    private func homeWidgetView(_ preference: HomeWidgetPreference) -> some View {
        switch preference.kind {
        case .missions:
            metricWidgetButton(route: .missions) {
                PhoneHomeMetricCard(
                    sectionTitle: String(localized: "home.hub.shortcut.missions.title"),
                    sectionIcon: "target",
                    title: String(localized: "home.hub.widget.nextMission.title"),
                    value: widget.nextMissionTitle ?? String(localized: "home.hub.widget.nextMission.empty"),
                    subtitle: widget.nextMissionTitle == nil
                        ? String(localized: "home.hub.widget.nextMission.subtitleEmpty")
                        : String(localized: "home.hub.widget.nextMission.subtitle"),
                    tint: AppTheme.FeatureColors.missionsAccent,
                    span: preference.span
                )
            }
        case .lists:
            metricWidgetButton(route: .lists) {
                PhoneHomeMetricCard(
                    sectionTitle: String(localized: "home.hub.shortcut.lists.title"),
                    sectionIcon: "checklist",
                    title: String(localized: "home.hub.widget.activeLists.title"),
                    value: "\(widget.activeListsCount)",
                    subtitle: String(localized: "home.hub.widget.activeLists.subtitle"),
                    tint: AppTheme.FeatureColors.listsAccent,
                    span: preference.span
                )
            }
        case .notes:
            metricWidgetButton(route: .notes) {
                PhoneHomeMetricCard(
                    sectionTitle: String(localized: "home.hub.shortcut.notes.title"),
                    sectionIcon: "note.text",
                    title: String(localized: "home.hub.widget.notes.title"),
                    value: "\(widget.notesCount)",
                    subtitle: String(localized: "home.hub.widget.notes.subtitle"),
                    tint: AppTheme.FeatureColors.notesAccent,
                    span: preference.span
                )
            }
        case .incidents:
            metricWidgetButton(route: .incidents) {
                PhoneHomeMetricCard(
                    sectionTitle: String(localized: "home.hub.shortcut.incidents.title"),
                    sectionIcon: "bolt.horizontal",
                    title: String(localized: "home.hub.widget.nearestIncident.title"),
                    value: widget.nearestIncidentTitle ?? String(localized: "home.hub.widget.nearestIncident.empty"),
                    subtitle: widget.nearestIncidentDateText ?? String(localized: "home.hub.widget.nearestIncident.subtitle"),
                    tint: AppTheme.FeatureColors.incidentsAccent,
                    span: preference.span
                )
            }
        case .routines:
            metricWidgetButton(route: .routines) {
                PhoneHomeMetricCard(
                    sectionTitle: String(localized: "navigation.item.routines"),
                    sectionIcon: "clock.arrow.circlepath",
                    title: String(localized: "home.routines.title"),
                    value: widget.routinesProgressText,
                    subtitle: widget.nextRoutineText ?? String(localized: "home.routines.empty"),
                    tint: AppTheme.FeatureColors.routinesAccent,
                    span: preference.span
                )
            }
        case .summary:
            PhoneTodaySummaryCard(widget: widget)
        case .budget:
            PhoneHomeBudgetCard(
                entries: widget.budgetEntries,
                range: $budgetRange,
                onOpen: { open(.budget) }
            )
        }
    }

    private func metricWidgetButton<Label: View>(route: PhoneHomeRoute, @ViewBuilder label: () -> Label) -> some View {
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
                    PhoneActiveSpaceMenuButton(space: selectedSpace)
                } else {
                    Image(systemName: "person.3.fill")
                        .font(.headline)
                }
            }
            .accessibilityLabel("spaces.selector.changeActive")
        }
    }
}

#endif
