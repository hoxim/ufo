#if os(iOS)

import SwiftUI
import SwiftData
import MapKit

struct PhoneLocationsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo
    @Environment(AppNotificationStore.self) private var notificationStore

    @State private var locationViewModel: PhoneLocationViewModel
    @State private var isPresentingAddPlace = false
    @State private var isShowingSavedPlacesMap = false
    @State private var isSubmittingNearbyCheckIn = false
    @State private var activeRelatedRoute: RelatedContentRoute?
    @State private var editingPlace: SavedPlace?
    @State private var placeToDelete: SavedPlace?

    init() {
        _locationViewModel = State(wrappedValue: PhoneLocationViewModel())
    }

    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    var body: some View {
        List {
                if let error = locationViewModel.locationErrorMessage {
                    messageRow(error, color: .orange)
                }

                if let error = locationViewModel.locationStore?.lastErrorMessage {
                    messageRow(error, color: .red)
                }

                Section {
                    PhoneLocationsMapCard(
                        region: $locationViewModel.region,
                        places: locationViewModel.locationStore?.savedPlaces ?? [],
                        latestPins: latestPins(),
                        currentLocation: locationViewModel.currentLocation
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                if let nearbyPlace = nearbyCheckInPlace {
                    Section("locations.section.nearby") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(format: String(localized: "locations.nearby.title"), nearbyPlace.name))
                                .font(.headline)

                            Text("locations.nearby.description")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button {
                                Task { await createNearbyCheckIn(for: nearbyPlace) }
                            } label: {
                                if isSubmittingNearbyCheckIn {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Text(String(format: String(localized: "locations.nearby.action"), nearbyPlace.name))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            .disabled(isSubmittingNearbyCheckIn)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("locations.section.places") {
                    if let places = locationViewModel.locationStore?.savedPlaces, !places.isEmpty {
                        ForEach(places) { place in
                            HStack(alignment: .top, spacing: 12) {
                                PhoneSavedPlaceRow(place: place)

                                Spacer(minLength: 8)

                                Menu {
                                    Button {
                                        activeRelatedRoute = .place(place.id)
                                    } label: {
                                        Label("locations.action.details", systemImage: "info.circle")
                                    }

                                    Button {
                                        editingPlace = place
                                    } label: {
                                        Label("common.edit", systemImage: "pencil")
                                    }

                                    Button(role: .destructive) {
                                        placeToDelete = place
                                    } label: {
                                        Label("common.delete", systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                activeRelatedRoute = .place(place.id)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    placeToDelete = place
                                } label: {
                                    Label("common.delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    editingPlace = place
                                } label: {
                                    Label("common.edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    } else {
                        ContentUnavailableView(
                            "locations.empty.places.title",
                            systemImage: "mappin.slash",
                            description: Text("locations.empty.places.description")
                        )
                    }
                }

                Section("locations.section.latestLocations") {
                    if latestPins().isEmpty {
                        Text("locations.empty.sharedLocations")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(latestPins()) { ping in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ping.userDisplayName)
                                Text(ping.recordedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("locations.section.checkIns") {
                    if let checkIns = locationViewModel.locationStore?.checkIns, !checkIns.isEmpty {
                        ForEach(checkIns.prefix(8)) { checkIn in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(checkIn.userDisplayName)
                                Text(checkIn.placeName ?? String(localized: "locations.currentLocation"))
                                    .font(.subheadline)
                                if let note = checkIn.note, !note.isEmpty {
                                    Text(note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(checkIn.checkedInAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text("locations.empty.checkIns")
                            .foregroundStyle(.secondary)
                    }
                }
        }
        .appPrimaryListChrome()
        .appScreenBackground()
        .navigationTitle("locations.view.title")
        .hideTabBarIfSupported()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingAddPlace = true
                } label: {
                    Label("locations.action.addPlace", systemImage: "plus")
                }
                .disabled(spaceRepo.selectedSpace == nil)
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    isShowingSavedPlacesMap = true
                } label: {
                    Label("locations.action.map", systemImage: "map")
                }
                .disabled((locationViewModel.locationStore?.savedPlaces.isEmpty ?? true) && locationViewModel.currentLocation == nil)
            }
        }
        .refreshable {
            await refreshPlaces()
        }
        .sheet(isPresented: $isPresentingAddPlace) {
            PhoneAddSavedPlaceSheet(
                viewModel: locationViewModel,
                actorId: authRepo.currentUser?.id
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $isShowingSavedPlacesMap) {
            PhoneSavedPlacesMapView(
                places: locationViewModel.locationStore?.savedPlaces ?? [],
                latestPins: latestPins(),
                currentLocation: locationViewModel.currentLocation,
                initialRegion: locationViewModel.region
            )
            .presentationDetents([.large])
        }
        .sheet(item: $editingPlace) { place in
            PhoneAddSavedPlaceSheet(
                viewModel: locationViewModel,
                actorId: authRepo.currentUser?.id,
                placeToEdit: place
            )
            .presentationDetents([.large])
        }
        .navigationDestination(item: $activeRelatedRoute) { route in
            RelatedContentDestinationView(route: route, originLabel: String(localized: "locations.view.title"))
        }
        .alert(
            "locations.alert.delete.title",
            isPresented: Binding(
                get: { placeToDelete != nil },
                set: { if !$0 { placeToDelete = nil } }
            ),
            presenting: placeToDelete
        ) { place in
            Button("common.delete", role: .destructive) {
                Task {
                    await locationViewModel.locationStore?.deleteSavedPlace(place, actor: authRepo.currentUser?.id)
                    placeToDelete = nil
                }
            }
            Button("common.cancel", role: .cancel) {
                placeToDelete = nil
            }
        } message: { place in
            Text(String(format: String(localized: "locations.alert.delete.message"), place.name))
        }
        .task {
            Log.msg("PhoneLocationsScreen.task start selectedSpace=\(spaceRepo.selectedSpace?.id.uuidString ?? "nil")")
            await locationViewModel.setup(modelContext: modelContext, spaceRepo: spaceRepo, isPreview: isPreview)
            consumeLocationSignals()
        }
        .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
            Log.msg("PhoneLocationsScreen selected space changed to \(newValue?.uuidString ?? "nil")")
            Task {
                await locationViewModel.handleSpaceChange(newValue)
                consumeLocationSignals()
            }
        }
        .onChange(of: locationViewModel.currentLocation?.coordinate.latitude) { _, _ in
            consumeLocationSignals()
        }
        .onChange(of: locationViewModel.currentLocation?.coordinate.longitude) { _, _ in
            consumeLocationSignals()
        }
        .onChange(of: locationViewModel.locationStore?.checkIns.count) { _, _ in
            consumeLocationSignals()
        }
        .onDisappear {
            locationViewModel.stopTracking()
        }
    }

    private var nearbyCheckInPlace: SavedPlace? {
        locationViewModel.suggestedCheckInPlace(for: authRepo.currentUser?.id)
    }

    private func latestPins() -> [LocationPing] {
        var seen: Set<UUID> = []
        var latest: [LocationPing] = []

        for ping in locationViewModel.locationStore?.pings ?? [] {
            if !seen.contains(ping.userId) {
                seen.insert(ping.userId)
                latest.append(ping)
            }
        }

        return latest
    }

    private func messageRow(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(color)
    }

    private func consumeLocationSignals() {
        locationViewModel.consumeNearbyCheckInSuggestion(
            for: authRepo.currentUser?.id,
            notificationStore: notificationStore
        )
        locationViewModel.consumeNewCheckIns(
            currentUserId: authRepo.currentUser?.id,
            notificationStore: notificationStore
        )
    }

    @MainActor
    private func refreshPlaces() async {
        await locationViewModel.locationStore?.syncPending()
        await locationViewModel.locationStore?.refreshRemote()
        locationViewModel.requestFreshLocation()
    }

    private func createNearbyCheckIn(for place: SavedPlace) async {
        guard
            let currentUser = authRepo.currentUser,
            let coordinate = locationViewModel.currentCoordinate()
        else {
            notificationStore.showToast(
                title: "Brak lokalizacji",
                message: "Nie udało się pobrać bieżącej lokalizacji do check-inu.",
                style: .warning
            )
            return
        }

        isSubmittingNearbyCheckIn = true
        defer { isSubmittingNearbyCheckIn = false }

        let checkIn = await locationViewModel.locationStore?.addCheckIn(
            userId: currentUser.id,
            userName: currentUser.effectiveDisplayName ?? currentUser.email,
            placeId: place.id,
            placeName: place.name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            note: nil,
            actor: currentUser.id
        )

        guard checkIn != nil else { return }

        notificationStore.addNotification(
            title: "Check-in zapisany",
            body: "Zapisaliśmy Twój check-in w miejscu \(place.name).",
            category: .info,
            priority: .normal,
            source: "location-self-checkin-\(place.id.uuidString)",
            toast: AppToast(
                title: "Check-in zapisany",
                message: place.name,
                style: .success
            )
        )

        consumeLocationSignals()
    }
}

#Preview("Locations") {
    let schema = Schema([
        UserProfile.self,
        Space.self,
        SpaceMembership.self,
        SpaceInvitation.self,
        Mission.self,
        Incident.self,
        LinkedThing.self,
        Assignment.self,
        LocationPing.self,
        SavedPlace.self,
        LocationCheckIn.self
    ])

    let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext

    let user = UserProfile(id: UUID(), email: "preview@ufo.app", fullName: "Parent", role: "admin")
    let child = UserProfile(id: UUID(), email: "child@ufo.app", fullName: "Child", role: "child")
    let space = Space(id: UUID(), name: "Family Crew", inviteCode: "UFO123")

    context.insert(user)
    context.insert(child)
    context.insert(space)
    context.insert(SpaceMembership(user: user, space: space, role: "admin"))
    context.insert(SpaceMembership(user: child, space: space, role: "child"))

    let school = SavedPlace(
        spaceId: space.id,
        name: "School",
        placeDescription: "Morning drop-off point",
        category: SavedPlaceCategory.school.rawValue,
        iconName: "building.columns.fill",
        iconColorHex: "#2563EB",
        address: "Marszalkowska 1, Warsaw",
        latitude: 52.23,
        longitude: 21.01,
        createdBy: user.id
    )
    context.insert(school)
    context.insert(LocationPing(spaceId: space.id, userId: child.id, userDisplayName: "Child", latitude: 52.23, longitude: 21.01))
    context.insert(LocationPing(spaceId: space.id, userId: user.id, userDisplayName: "Parent", latitude: 52.24, longitude: 21.02))
    context.insert(LocationCheckIn(spaceId: space.id, userId: child.id, userDisplayName: "Child", placeId: school.id, placeName: school.name, latitude: school.latitude, longitude: school.longitude, note: "Waiting after class"))

    try? context.save()

    let authRepo = AuthRepository(client: SupabaseConfig.client, isLoggedIn: true, currentUser: user)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    spaceRepo.selectedSpace = space

    return PhoneLocationsScreen()
        .environment(authRepo)
        .environment(spaceRepo)
        .modelContainer(container)
}

#endif
