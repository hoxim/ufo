import SwiftUI
import SwiftData
import MapKit

struct LocationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo

    @State private var locationStore: LocationStore?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122),
        span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
    )
    @State private var latitudeText = "52.2297"
    @State private var longitudeText = "21.0122"

    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Map(coordinateRegion: $region, annotationItems: latestPins()) { pin in
                    MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)) {
                        VStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(.red)
                            Text(pin.userDisplayName)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.thinMaterial, in: Capsule())
                        }
                    }
                }
                .frame(minHeight: 280)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .onAppear {
                    centerOnLatestPin()
                }

                Form {
                    if let error = locationStore?.lastErrorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Section("Quick update") {
                        TextField("Latitude", text: $latitudeText)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        TextField("Longitude", text: $longitudeText)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif

                        Button("Save my location") {
                            Task { await addLocationPing() }
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("Family Map")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await locationStore?.syncPending() }
                    } label: {
                        Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }
            .task { await setupStoreIfNeeded() }
            .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
                locationStore?.setSpace(newValue)
                Task { await locationStore?.refreshRemote() }
            }
            .onChange(of: locationStore?.pings.count) { _, _ in
                centerOnLatestPin()
            }
        }
    }

    private func latestPins() -> [LocationPing] {
        var seen: Set<UUID> = []
        var latest: [LocationPing] = []

        for ping in locationStore?.pings ?? [] {
            if !seen.contains(ping.userId) {
                seen.insert(ping.userId)
                latest.append(ping)
            }
        }

        return latest
    }

    private func centerOnLatestPin() {
        guard let first = latestPins().first else { return }
        region.center = CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)
    }

    private func addLocationPing() async {
        guard
            let latitude = Double(latitudeText.replacingOccurrences(of: ",", with: ".")),
            let longitude = Double(longitudeText.replacingOccurrences(of: ",", with: ".")),
            let user = authRepo.currentUser
        else {
            locationStore?.lastErrorMessage = "Niepoprawne współrzędne lub użytkownik."
            return
        }

        await locationStore?.addPing(
            userId: user.id,
            userName: user.fullName ?? user.email,
            latitude: latitude,
            longitude: longitude,
            actor: user.id
        )
    }

    @MainActor
    private func setupStoreIfNeeded() async {
        guard locationStore == nil else { return }

        let repo = LocationRepository(client: SupabaseConfig.client, context: modelContext)
        let store = LocationStore(modelContext: modelContext, repository: repo)
        locationStore = store
        store.setSpace(spaceRepo.selectedSpace?.id)

        if !isPreview {
            await store.refreshRemote()
        }
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

    try? context.save()

    let authRepo = AuthRepository(client: SupabaseConfig.client, isLoggedIn: true, currentUser: user)
    let spaceRepo = SpaceRepository(client: SupabaseConfig.client)
    spaceRepo.selectedSpace = space

    return LocationsView()
        .environment(authRepo)
        .environment(spaceRepo)
        .modelContainer(container)
}
