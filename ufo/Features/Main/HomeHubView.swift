import SwiftUI
import SwiftData

struct HomeHubView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthStore.self) private var authStore
    @Environment(SpaceRepository.self) private var spaceRepository

    @State private var showProfileSheet = false
    @State private var widget = HomeWidgetState()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    HomeWidgetLink {
                        MissionsListView()
                    } content: {
                        HomeMetricCard(
                            title: "Next mission",
                            value: widget.nextMissionTitle ?? "No active mission",
                            subtitle: widget.nextMissionTitle == nil ? "Create one in Missions" : "Tap to open Missions",
                            tint: .orange
                        )
                    }

                    HStack(spacing: 12) {
                        HomeWidgetLink {
                            SharedListsView()
                        } content: {
                            HomeMetricCard(
                                title: "Active lists",
                                value: "\(widget.activeListsCount)",
                                subtitle: "Shared list count",
                                tint: .pink
                            )
                        }
                        HomeWidgetLink {
                            NotesView()
                        } content: {
                            HomeMetricCard(
                                title: "Notes",
                                value: "\(widget.notesCount)",
                                subtitle: "Notes in this space",
                                tint: .blue
                            )
                        }
                    }

                    HStack(spacing: 12) {
                        HomeWidgetLink {
                            IncidentsListView()
                        } content: {
                            HomeMetricCard(
                                title: "Nearest incident",
                                value: widget.nearestIncidentTitle ?? "No upcoming event",
                                subtitle: widget.nearestIncidentDateText ?? "Tap to open Incidents",
                                tint: .red
                            )
                        }
                        HomeWidgetLink {
                            LinksListView()
                        } content: {
                            HomeMetricCard(
                                title: "Latest links",
                                value: "\(widget.linksCount)",
                                subtitle: widget.latestLinkDateText ?? "No links yet",
                                tint: .green
                            )
                        }
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                        HomeShortcutCard(title: "Missions", subtitle: "Tasks and progress", icon: "target") {
                            MissionsListView()
                        }
                        HomeShortcutCard(title: "Incidents", subtitle: "Events and history", icon: "bolt.horizontal") {
                            IncidentsListView()
                        }
                        HomeShortcutCard(title: "Lists", subtitle: "Shared checklists", icon: "checklist") {
                            SharedListsView()
                        }
                        HomeShortcutCard(title: "Links", subtitle: "Connected items", icon: "link") {
                            LinksListView()
                        }
                        HomeShortcutCard(title: "Notes", subtitle: "Ideas and context", icon: "note.text") {
                            NotesView()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Podsumowanie")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showProfileSheet = true
                    } label: {
                        AvatarCircle(user: authStore.currentUser)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open profile panel")
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
        }
    }

    /// Refreshes Home widgets using local data from current selected space.
    private func refreshWidgets() {
        guard let spaceId = spaceRepository.selectedSpace?.id else {
            widget = HomeWidgetState()
            return
        }

        let missions = (try? modelContext.fetch(
            FetchDescriptor<Mission>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil && $0.isCompleted == false },
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
        )) ?? []

        let lists = (try? modelContext.fetch(
            FetchDescriptor<SharedList>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil }
            )
        )) ?? []

        let notes = (try? modelContext.fetch(
            FetchDescriptor<Note>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil }
            )
        )) ?? []

        let allIncidents = (try? modelContext.fetch(
            FetchDescriptor<Incident>(
                predicate: #Predicate { $0.spaceId == spaceId && $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.occurrenceDate, order: .forward)]
            )
        )) ?? []
        let nearestIncident = allIncidents.first(where: { $0.occurrenceDate >= Date.now })

        let latestLink = (try? modelContext.fetch(
            FetchDescriptor<LinkedThing>(
                predicate: #Predicate { $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        ))?.first

        let linksCount = (try? modelContext.fetch(
            FetchDescriptor<LinkedThing>(
                predicate: #Predicate { $0.deletedAt == nil }
            )
        ))?.count ?? 0

        widget = HomeWidgetState(
            nextMissionTitle: missions.first?.title,
            activeListsCount: lists.count,
            notesCount: notes.count,
            nearestIncidentTitle: nearestIncident?.title,
            nearestIncidentDateText: nearestIncident?.occurrenceDate.formatted(date: .abbreviated, time: .shortened),
            linksCount: linksCount,
            latestLinkDateText: latestLink?.updatedAt.formatted(date: .abbreviated, time: .shortened)
        )
    }
}

private struct HomeWidgetState {
    var nextMissionTitle: String?
    var activeListsCount: Int = 0
    var notesCount: Int = 0
    var nearestIncidentTitle: String?
    var nearestIncidentDateText: String?
    var linksCount: Int = 0
    var latestLinkDateText: String?
}

private struct HomeWidgetLink<Destination: View, Content: View>: View {
    @ViewBuilder let destination: Destination
    @ViewBuilder let content: Content

    init(
        @ViewBuilder destination: () -> Destination,
        @ViewBuilder content: () -> Content
    ) {
        self.destination = destination()
        self.content = content()
    }

    var body: some View {
        NavigationLink {
            destination
        } label: {
            content
        }
        .buttonStyle(.plain)
    }
}

private struct HomeMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
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

private struct HomeShortcutCard<Destination: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    @ViewBuilder var destination: Destination

    init(
        title: String,
        subtitle: String,
        icon: String,
        @ViewBuilder destination: () -> Destination
    ) {
        // The initializer stores card metadata and eagerly builds destination view.
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.destination = destination()
    }

    var body: some View {
        NavigationLink {
            destination
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
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
            } else if let urlString = user?.avatarURL, let url = URL(string: urlString) {
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
                Text(user?.fullName?.prefix(1) ?? "U")
                    .foregroundStyle(.white)
                    .fontWeight(.bold)
            }
    }
}

#Preview("Home Hub") {
    let schema = Schema([
        UserProfile.self,
        Space.self,
        SpaceMembership.self,
        Mission.self,
        SharedList.self,
        Note.self
    ])
    let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext

    let user = UserProfile(id: UUID(), email: "preview@ufo.app", fullName: "Preview User", role: "admin")
    let space = Space(id: UUID(), name: "Family Crew", inviteCode: "UFO123")
    context.insert(user)
    context.insert(space)
    context.insert(SpaceMembership(user: user, space: space, role: "admin"))
    context.insert(Mission(spaceId: space.id, title: "Buy food", missionDescription: "Weekly shopping", difficulty: 2))
    context.insert(SharedList(spaceId: space.id, name: "Shopping list", type: "shopping"))
    context.insert(Note(spaceId: space.id, title: "Reminder", content: "Take umbrella", createdBy: user.id))
    try? context.save()

    let authRepo = AuthRepository(client: SupabaseConfig.client, isLoggedIn: true, currentUser: user)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    spaceRepo.selectedSpace = space
    let authStore = AuthStore(authRepository: authRepo, spaceRepository: spaceRepo)
    authStore.state = .ready

    return HomeHubView()
        .environment(authStore)
        .environment(spaceRepo)
        .modelContainer(container)
}
