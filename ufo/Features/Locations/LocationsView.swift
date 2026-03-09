import SwiftUI
import SwiftData
import MapKit

struct LocationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo
    
    @State private var locationViewModel: LocationViewModel
    
    init() {
        _locationViewModel = State(wrappedValue: LocationViewModel())
    }
    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    var body: some View {
        NavigationStack {
            ZStack {
#if os(iOS)
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea(edges: .all)
#else
                Color(nsColor: .windowBackgroundColor).ignoresSafeArea(edges: .all)
#endif
                
                VStack(spacing: 12) {
                    MapSectionView(
                        region: $locationViewModel.region,
                        pins: latestPins(),
                        currentLocation: locationViewModel.currentLocation,
                        onAppear: centerOnLatestPin
                    )
                    
                    Form {
                        if let error = locationViewModel.locationErrorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }

                        if let error = locationViewModel.locationStore?.lastErrorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        Section("locations.view.section.add") {
                            Button {
                                locationViewModel.useCurrentLocationForInput()
                            } label: {
                                Label("locations.view.action.useCurrent", systemImage: "location.fill")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            TextField("locations.view.field.latitude", text: $locationViewModel.latitudeText)
#if os(iOS)
                                .keyboardType(.decimalPad)
#endif
                            TextField("locations.view.field.longitude", text: $locationViewModel.longitudeText)
#if os(iOS)
                                .keyboardType(.decimalPad)
#endif
                            
                            Button("locations.view.action.saveMine") {
                                Task { await addLocationPing() }
                            }
                            .frame(maxWidth: .infinity)
                            .disabled(authRepo.currentUser == nil)
                        }
                        
                    }
                }
                .padding()
                .navigationTitle("locations.view.title")
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button {
                            Task { await locationViewModel.locationStore?.syncPending() }
                        } label: {
                            Label("common.sync", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                }
                .task {
                    await locationViewModel.setup(modelContext: modelContext, spaceRepo: spaceRepo, isPreview: isPreview)
                }
                .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
                    Task { await locationViewModel.handleSpaceChange(newValue) }
                }
                .onChange(of: locationViewModel.locationStore?.pings.count) { _, _ in
                    centerOnLatestPin()
                }
                .onDisappear {
                    locationViewModel.stopTracking()
                }
            }
        }
    }

    /// Handles latest pins.
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

    /// Handles center on latest pin.
    private func centerOnLatestPin() {
        locationViewModel.centerOnLatestPin()
    }

    /// Handles add location ping.
    private func addLocationPing() async {
        guard
            let coordinate = locationViewModel.parsedInputCoordinate(),
            let user = authRepo.currentUser
        else {
            locationViewModel.locationStore?.lastErrorMessage = String(localized: "locations.error.invalidInput")
            return
        }

        await locationViewModel.locationStore?.addPing(
            userId: user.id,
            userName: user.fullName ?? user.email,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            actor: user.id
        )
    }
}

private struct MapSectionView: View {
    @Binding var region: MKCoordinateRegion
    let pins: [LocationPing]
    let currentLocation: CLLocation?
    let onAppear: () -> Void

    var body: some View {
        Group {
            if #available(iOS 17.0, macOS 14.0, *) {
                Map {
                    ForEach(annotationItems) { item in
                        Marker("", coordinate: item.coordinate)
                            .tint(item.tint)
                    }
                }
            } else {
                Map(coordinateRegion: $region, annotationItems: annotationItems) { item in
                    MapMarker(coordinate: item.coordinate, tint: item.tint)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if currentLocation != nil {
                Label("locations.view.currentPosition", systemImage: "location.fill")
                    .font(.caption)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(8)
            }
        }
        .frame(minHeight: 280)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            onAppear()
        }
    }

    /// Builds one annotation item list for map.
    private var annotationItems: [MapPoint] {
        var values: [MapPoint] = pins.map { pin in
            MapPoint(
                id: pin.id,
                coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude),
                tint: .red
            )
        }
        if let currentLocation {
            values.insert(
                MapPoint(
                    id: UUID(),
                    coordinate: currentLocation.coordinate,
                    tint: .blue
                ),
                at: 0
            )
        }
        return values
    }
}

private struct MapPoint: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let tint: Color
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
        LocationPing.self
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

    context.insert(LocationPing(spaceId: space.id, userId: child.id, userDisplayName: "Child", latitude: 52.23, longitude: 21.01))
    context.insert(LocationPing(spaceId: space.id, userId: user.id, userDisplayName: "Parent", latitude: 52.24, longitude: 21.02))

    do {
        try context.save()
    } catch {
        Log.dbError("Locations preview context.save", error)
    }

    let authRepo = AuthRepository(client: SupabaseConfig.client, isLoggedIn: true, currentUser: user)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    spaceRepo.selectedSpace = space

    return LocationsView()
        .environment(authRepo)
        .environment(spaceRepo)
        .modelContainer(container)
}
