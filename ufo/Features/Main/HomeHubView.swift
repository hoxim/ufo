import SwiftUI
import SwiftData
import Charts

struct HomeHubView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthStore.self) private var authStore
    @Environment(SpaceRepository.self) private var spaceRepository
    @Environment(AppNotificationStore.self) private var notificationStore

    @State private var showProfileSheet = false
    @State private var showNotificationSheet = false
    @State private var widget = HomeWidgetState()
    @State private var budgetRange: BudgetWidgetRange = .month
    @State private var activeRoute: HomeRoute?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Button {
                        open(.missions)
                    } label: {
                        HomeMetricCard(
                            sectionTitle: String(localized: "home.hub.shortcut.missions.title"),
                            title: String(localized: "home.hub.widget.nextMission.title"),
                            value: widget.nextMissionTitle ?? String(localized: "home.hub.widget.nextMission.empty"),
                            subtitle: widget.nextMissionTitle == nil
                                ? String(localized: "home.hub.widget.nextMission.subtitleEmpty")
                                : String(localized: "home.hub.widget.nextMission.subtitle"),
                            tint: .orange
                        )
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 12) {
                        Button {
                            open(.lists)
                        } label: {
                            HomeMetricCard(
                                sectionTitle: String(localized: "home.hub.shortcut.lists.title"),
                                title: String(localized: "home.hub.widget.activeLists.title"),
                                value: "\(widget.activeListsCount)",
                                subtitle: String(localized: "home.hub.widget.activeLists.subtitle"),
                                tint: .pink
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            open(.notes)
                        } label: {
                            HomeMetricCard(
                                sectionTitle: String(localized: "home.hub.shortcut.notes.title"),
                                title: String(localized: "home.hub.widget.notes.title"),
                                value: "\(widget.notesCount)",
                                subtitle: String(localized: "home.hub.widget.notes.subtitle"),
                                tint: .blue
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 12) {
                        Button {
                            open(.incidents)
                        } label: {
                            HomeMetricCard(
                                sectionTitle: String(localized: "home.hub.shortcut.incidents.title"),
                                title: String(localized: "home.hub.widget.nearestIncident.title"),
                                value: widget.nearestIncidentTitle ?? String(localized: "home.hub.widget.nearestIncident.empty"),
                                subtitle: widget.nearestIncidentDateText ?? String(localized: "home.hub.widget.nearestIncident.subtitle"),
                                tint: .red
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            open(.links)
                        } label: {
                            HomeMetricCard(
                                sectionTitle: String(localized: "home.hub.shortcut.links.title"),
                                title: String(localized: "home.hub.widget.latestLinks.title"),
                                value: "\(widget.linksCount)",
                                subtitle: widget.latestLinkDateText ?? String(localized: "home.hub.widget.latestLinks.empty"),
                                tint: .green
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    TodaySummaryCard(widget: widget)

                    HomeBudgetCard(
                        entries: widget.budgetEntries,
                        range: $budgetRange,
                        onOpen: { open(.budget) }
                    )
                }
                .padding()
            }
            .navigationTitle(spaceRepository.selectedSpace?.name ?? "Summary")
            .navigationDestination(item: $activeRoute) { route in
                destination(for: route)
            }
            .toolbar {
                ToolbarItem(placement: homeSpaceToolbarPlacement) {
                    spaceSwitcher
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            open(.quickAddMission)
                        } label: {
                            Label("Add Mission", systemImage: "target")
                        }

                        Button {
                            open(.quickAddIncident)
                        } label: {
                            Label("Add Incident", systemImage: "bolt.horizontal")
                        }

                        Button {
                            open(.quickAddList)
                        } label: {
                            Label("Add List", systemImage: "checklist")
                        }

                        Button {
                            open(.quickAddBudgetEntry)
                        } label: {
                            Label("Add Budget Entry", systemImage: "dollarsign.circle")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Quick add")
                }

                ToolbarItem(placement: profileToolbarPlacement) {
                    Button {
                        showNotificationSheet = true
                    } label: {
                        NotificationBellButton(unreadCount: notificationStore.unreadCount)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open notifications")
                }

                ToolbarItem(placement: profileToolbarPlacement) {
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
            .onChange(of: spaceRepository.selectedSpace?.id) { _, _ in
                refreshWidgets()
            }
            .sheet(isPresented: $showProfileSheet) {
                ProfileHubView()
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showNotificationSheet) {
                NotificationCenterView()
                    .presentationDetents([.medium, .large])
            }
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
        case .locations:
            LocationsView()
        case .links:
            LinksListView()
        case .budget:
            BudgetView()
        case .quickAddMission:
            MissionsListView(autoPresentAdd: true)
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

            let latestLink = try modelContext.fetch(
                FetchDescriptor<LinkedThing>(
                    predicate: #Predicate { $0.deletedAt == nil },
                    sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
                )
            ).first

            let linksCount = try modelContext.fetch(
                FetchDescriptor<LinkedThing>(
                    predicate: #Predicate { $0.deletedAt == nil }
                )
            ).count

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
                linksCount: linksCount,
                latestLinkDateText: latestLink?.updatedAt.formatted(date: .abbreviated, time: .shortened),
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

private struct NotificationBellButton: View {
    let unreadCount: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 36, height: 36)

            Image(systemName: unreadCount > 0 ? "bell.badge.fill" : "bell")
                .font(.title3)
                .foregroundStyle(.primary)
        }
        .frame(width: 44, height: 44)
        .overlay(alignment: .topTrailing) {
            if unreadCount > 0 {
                Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, unreadCount > 9 ? 5 : 4)
                    .padding(.vertical, 2)
                    .background(Color.red, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.white, lineWidth: 2)
                    }
                    .offset(x: 1, y: 6)
            }
        }
    }
}

private struct ActiveSpaceMenuButton: View {
    let space: Space

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(space.type == .personal || space.type == .private ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: "person.3.fill")
                        .font(.caption.bold())
                        .foregroundStyle(space.type == .personal || space.type == .private ? .orange : .blue)
                }

            Image(systemName: "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private enum HomeRoute: Hashable, Identifiable {
    case missions
    case lists
    case notes
    case incidents
    case locations
    case links
    case budget
    case quickAddMission
    case quickAddIncident
    case quickAddList
    case quickAddBudgetEntry

    var id: String {
        switch self {
        case .missions: "missions"
        case .lists: "lists"
        case .notes: "notes"
        case .incidents: "incidents"
        case .locations: "locations"
        case .links: "links"
        case .budget: "budget"
        case .quickAddMission: "quickAddMission"
        case .quickAddIncident: "quickAddIncident"
        case .quickAddList: "quickAddList"
        case .quickAddBudgetEntry: "quickAddBudgetEntry"
        }
    }
}

private enum BudgetWidgetRange: CaseIterable {
    case today
    case week
    case month

    var title: String {
        switch self {
        case .today: "Today"
        case .week: "Week"
        case .month: "Month"
        }
    }

    var days: Int {
        switch self {
        case .today: 1
        case .week: 7
        case .month: 30
        }
    }
}

private struct HomeWidgetState {
    var nextMissionTitle: String?
    var activeListsCount: Int = 0
    var notesCount: Int = 0
    var nearestIncidentTitle: String?
    var nearestIncidentDateText: String?
    var dueTodayCount: Int = 0
    var recurringMissionCount: Int = 0
    var pinnedNotesCount: Int = 0
    var openIncidentsCount: Int = 0
    var criticalIncidentsCount: Int = 0
    var savedPlacesCount: Int = 0
    var recentCheckInText: String?
    var linksCount: Int = 0
    var latestLinkDateText: String?
    var budgetEntries: [BudgetEntry] = []
}

private struct TodaySummaryCard: View {
    let widget: HomeWidgetState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today / Family Hub")
                .font(.headline)

            HStack(spacing: 12) {
                summaryPill(title: "Due today", value: "\(widget.dueTodayCount)", tint: .orange)
                summaryPill(title: "Recurring", value: "\(widget.recurringMissionCount)", tint: .blue)
                summaryPill(title: "Pinned", value: "\(widget.pinnedNotesCount)", tint: .pink)
            }

            HStack(spacing: 12) {
                summaryPill(title: "Open", value: "\(widget.openIncidentsCount)", tint: .red)
                summaryPill(title: "Critical", value: "\(widget.criticalIncidentsCount)", tint: .red.opacity(0.8))
                summaryPill(title: "Places", value: "\(widget.savedPlacesCount)", tint: .green)
            }

            if let recentCheckInText = widget.recentCheckInText {
                Label(recentCheckInText, systemImage: "location.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No recent check-ins")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func summaryPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct HomeBudgetCard: View {
    let entries: [BudgetEntry]
    @Binding var range: BudgetWidgetRange
    let onOpen: () -> Void

    private var filteredEntries: [BudgetEntry] {
        let start = Calendar.current.date(byAdding: .day, value: -(range.days - 1), to: Date()) ?? Date()
        return entries.filter { $0.entryDate >= start }
    }

    private var balance: Double {
        filteredEntries.reduce(0) { partial, entry in
            partial + (entry.kind == BudgetEntryKind.expense.rawValue ? -entry.amount : entry.amount)
        }
    }

    private var income: Double {
        filteredEntries
            .filter { $0.kind == BudgetEntryKind.income.rawValue }
            .reduce(0) { $0 + $1.amount }
    }

    private var expense: Double {
        filteredEntries
            .filter { $0.kind == BudgetEntryKind.expense.rawValue }
            .reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("Budget")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onOpen) {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                ForEach(BudgetWidgetRange.allCases, id: \.self) { option in
                    Button {
                        range = option
                    } label: {
                        Text(option.title)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(range == option ? Color.accentColor.opacity(0.2) : Color.white.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Balance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(balance.formatted(.currency(code: "PLN")))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(balance >= 0 ? .green : .red)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Income")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(income.formatted(.currency(code: "PLN")))
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Expense")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(expense.formatted(.currency(code: "PLN")))
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }

            if filteredEntries.isEmpty {
                Text("No entries in selected period")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Chart(filteredEntries.suffix(10)) { entry in
                    BarMark(
                        x: .value("Date", entry.entryDate, unit: .day),
                        y: .value("Amount", entry.kind == BudgetEntryKind.expense.rawValue ? -entry.amount : entry.amount)
                    )
                    .foregroundStyle(entry.kind == BudgetEntryKind.expense.rawValue ? .red : .green)
                }
                .frame(height: 140)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            onOpen()
        }
    }
}

private struct HomeMetricCard: View {
    let sectionTitle: String
    let title: String
    let value: String
    let subtitle: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(sectionTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(tint)
                .lineLimit(2)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct AvatarCircle: View {
    let user: UserProfile?

    var body: some View {
        Group {
            if let user, let localURL = AvatarCache.shared.existingURL(userId: user.id, version: user.avatarVersion) {
                AsyncImage(url: localURL) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        fallbackAvatar
                    }
                }
            } else if let urlString = user?.effectiveAvatarURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        fallbackAvatar
                    }
                }
            } else {
                fallbackAvatar
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
    }

    /// Returns default avatar view when no user image is available.
    private var fallbackAvatar: some View {
        Circle()
            .fill(Color.accentColor.gradient)
            .overlay {
                Text(user?.effectiveDisplayName?.prefix(1) ?? "U")
                    .foregroundStyle(.white)
                    .fontWeight(.bold)
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
        LocationCheckIn.self
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

    return HomeHubView()
        .environment(authStore)
        .environment(spaceRepo)
        .environment(notificationStore)
        .modelContainer(container)
}
