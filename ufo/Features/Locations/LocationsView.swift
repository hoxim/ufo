import SwiftUI
import SwiftData
import MapKit

struct LocationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpaceRepository.self) private var spaceRepo
    @Environment(AuthRepository.self) private var authRepo
    @Environment(AppNotificationStore.self) private var notificationStore

    @State private var locationViewModel: LocationViewModel
    @State private var isPresentingAddPlace = false
    @State private var isShowingSavedPlacesMap = false
    @State private var isSubmittingNearbyCheckIn = false

    init() {
        _locationViewModel = State(wrappedValue: LocationViewModel())
    }

    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    var body: some View {
        NavigationStack {
            List {
                if let error = locationViewModel.locationErrorMessage {
                    messageRow(error, color: .orange)
                }

                if let error = locationViewModel.locationStore?.lastErrorMessage {
                    messageRow(error, color: .red)
                }

                Section {
                    LocationsMapCard(
                        region: $locationViewModel.region,
                        places: locationViewModel.locationStore?.savedPlaces ?? [],
                        latestPins: latestPins(),
                        currentLocation: locationViewModel.currentLocation,
                        onUseMapCenter: {
                            locationViewModel.useMapCenterForInput()
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                if let nearbyPlace = nearbyCheckInPlace {
                    Section("Nearby") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("You are close to \(nearbyPlace.name)")
                                .font(.headline)

                            Text("The app detected that you are within the saved radius of this place. You can save a check-in right away.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button {
                                Task { await createNearbyCheckIn(for: nearbyPlace) }
                            } label: {
                                if isSubmittingNearbyCheckIn {
                                    ProgressView()
                                } else {
                                    Label("Check in at \(nearbyPlace.name)", systemImage: "mappin.and.ellipse")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isSubmittingNearbyCheckIn)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Saved Places") {
                    if let places = locationViewModel.locationStore?.savedPlaces, !places.isEmpty {
                        ForEach(places) { place in
                            SavedPlaceRow(place: place)
                        }
                    } else {
                        ContentUnavailableView(
                            "No saved places yet",
                            systemImage: "mappin.slash",
                            description: Text("Add places like home, school, work or dentist to reuse them across the app.")
                        )
                    }
                }

                Section("Latest Family Locations") {
                    if latestPins().isEmpty {
                        Text("No shared locations yet")
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

                Section("Recent Check-Ins") {
                    if let checkIns = locationViewModel.locationStore?.checkIns, !checkIns.isEmpty {
                        ForEach(checkIns.prefix(8)) { checkIn in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(checkIn.userDisplayName)
                                Text(checkIn.placeName ?? "Current location")
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
                        Text("No recent check-ins")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Locations")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingAddPlace = true
                    } label: {
                        Label("Add Place", systemImage: "plus")
                    }
                    .disabled(spaceRepo.selectedSpace == nil)
                }

                ToolbarItem(placement: .automatic) {
                    Button {
                        isShowingSavedPlacesMap = true
                    } label: {
                        Label("Map", systemImage: "map")
                    }
                    .disabled((locationViewModel.locationStore?.savedPlaces.isEmpty ?? true) && locationViewModel.currentLocation == nil)
                }

                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await locationViewModel.locationStore?.syncPending() }
                    } label: {
                        Label("common.sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }
            .sheet(isPresented: $isPresentingAddPlace) {
                AddSavedPlaceSheet(
                    viewModel: locationViewModel,
                    actorId: authRepo.currentUser?.id
                )
                #if os(iOS)
                .presentationDetents([.large])
                #endif
            }
            .sheet(isPresented: $isShowingSavedPlacesMap) {
                SavedPlacesMapView(
                    places: locationViewModel.locationStore?.savedPlaces ?? [],
                    latestPins: latestPins(),
                    currentLocation: locationViewModel.currentLocation,
                    initialRegion: locationViewModel.region
                )
                #if os(iOS)
                .presentationDetents([.large])
                #endif
            }
            .task {
                Log.msg("LocationsView.task start selectedSpace=\(spaceRepo.selectedSpace?.id.uuidString ?? "nil")")
                await locationViewModel.setup(modelContext: modelContext, spaceRepo: spaceRepo, isPreview: isPreview)
                consumeLocationSignals()
            }
            .onChange(of: spaceRepo.selectedSpace?.id) { _, newValue in
                Log.msg("LocationsView selected space changed to \(newValue?.uuidString ?? "nil")")
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

struct SavedPlacesMapView: View {
    @Environment(\.dismiss) private var dismiss

    let places: [SavedPlace]
    let latestPins: [LocationPing]
    let currentLocation: CLLocation?
    let initialRegion: MKCoordinateRegion

    @State private var region: MKCoordinateRegion

    init(
        places: [SavedPlace],
        latestPins: [LocationPing],
        currentLocation: CLLocation?,
        initialRegion: MKCoordinateRegion
    ) {
        self.places = places
        self.latestPins = latestPins
        self.currentLocation = currentLocation
        self.initialRegion = initialRegion
        _region = State(initialValue: initialRegion)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Map(coordinateRegion: $region, annotationItems: annotations) { item in
                    MapMarker(coordinate: item.coordinate, tint: item.tint)
                }
                .ignoresSafeArea(edges: .bottom)

                if !places.isEmpty {
                    List(places) { place in
                        SavedPlaceRow(place: place)
                    }
                    .frame(maxHeight: 260)
                }
            }
            .navigationTitle("Places Map")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var annotations: [LocationAnnotation] {
        var items = places.map {
            LocationAnnotation(
                id: $0.id,
                coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                tint: .teal
            )
        }
        items.append(
            contentsOf: latestPins.map {
                LocationAnnotation(
                    id: $0.id,
                    coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                    tint: .red
                )
            }
        )
        if let currentLocation {
            items.append(
                LocationAnnotation(
                    id: UUID(),
                    coordinate: currentLocation.coordinate,
                    tint: .blue
                )
            )
        }
        return items
    }
}

private struct SavedPlaceRow: View {
    let place: SavedPlace

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: place.iconName ?? "mappin.circle.fill")
                .font(.title3)
                .foregroundStyle(Color(hex: place.iconColorHex ?? "#0F766E"))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 5) {
                Text(place.name)
                    .font(.headline)

                Text(place.resolvedCategory.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let description = place.placeDescription, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let address = place.address, !address.isEmpty {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("\(place.latitude.formatted(.number.precision(.fractionLength(5)))) , \(place.longitude.formatted(.number.precision(.fractionLength(5))))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct LocationsMapCard: View {
    @Binding var region: MKCoordinateRegion
    let places: [SavedPlace]
    let latestPins: [LocationPing]
    let currentLocation: CLLocation?
    let onUseMapCenter: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(coordinateRegion: $region, annotationItems: annotations) { item in
                MapMarker(coordinate: item.coordinate, tint: item.tint)
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 18))

            Image(systemName: "plus")
                .font(.headline.bold())
                .foregroundStyle(.primary)
                .padding(12)
                .background(.ultraThinMaterial, in: Circle())

            VStack(alignment: .leading, spacing: 8) {
                if currentLocation != nil {
                    Label("Current location available", systemImage: "location.fill")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                Spacer()

                Button {
                    onUseMapCenter()
                } label: {
                    Label("Use map center", systemImage: "scope")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var annotations: [LocationAnnotation] {
        var items = places.map {
            LocationAnnotation(
                id: $0.id,
                coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                tint: .teal
            )
        }
        items.append(
            contentsOf: latestPins.map {
                LocationAnnotation(
                    id: $0.id,
                    coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                    tint: .red
                )
            }
        )
        if let currentLocation {
            items.append(
                LocationAnnotation(
                    id: UUID(),
                    coordinate: currentLocation.coordinate,
                    tint: .blue
                )
            )
        }
        return items
    }
}

private struct LocationAnnotation: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let tint: Color
}

private enum SavedPlaceInputMethod: String, CaseIterable, Identifiable {
    case address
    case currentLocation
    case coordinates
    case mapCenter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .address:
            return "Address"
        case .currentLocation:
            return "Current"
        case .coordinates:
            return "Coords"
        case .mapCenter:
            return "Map"
        }
    }
}

private struct AddSavedPlaceSheet: View {
    @Environment(\.dismiss) private var dismiss

    let viewModel: LocationViewModel
    let actorId: UUID?

    @State private var title = ""
    @State private var description = ""
    @State private var address = ""
    @State private var iconName = "mappin.circle.fill"
    @State private var iconColorHex = "#0F766E"
    @State private var category: SavedPlaceCategory = .other
    @State private var method: SavedPlaceInputMethod = .address
    @State private var latitudeText = ""
    @State private var longitudeText = ""
    @State private var isSaving = false
    @State private var isResolvingAddress = false
    @State private var showStylePicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Place") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Address", text: $address, axis: .vertical)
                        .lineLimit(2...3)
                    Picker("Category", selection: $category) {
                        ForEach(SavedPlaceCategory.allCases) { category in
                            Text(category.title).tag(category)
                        }
                    }
                }

                Section("Source") {
                    Picker("Input method", selection: $method) {
                        ForEach(SavedPlaceInputMethod.allCases) { method in
                            Text(method.title).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)

                    if method == .address {
                        Button {
                            Task { await resolveAddress() }
                        } label: {
                            if isResolvingAddress {
                                ProgressView()
                            } else {
                                Label("Find address on map", systemImage: "magnifyingglass")
                            }
                        }
                    }

                    if method == .currentLocation {
                        Button {
                            viewModel.useCurrentLocationForInput()
                            syncCoordinatesFromViewModel()
                            Task { await fillAddressFromCurrentLocation() }
                        } label: {
                            Label("Use current location", systemImage: "location.fill")
                        }
                    }

                    if method == .coordinates || method == .address {
                        TextField("Latitude", text: $latitudeText)
#if os(iOS)
                            .keyboardType(.decimalPad)
#endif
                        TextField("Longitude", text: $longitudeText)
#if os(iOS)
                            .keyboardType(.decimalPad)
#endif
                    }

                    if method == .mapCenter {
                        Text("Move the map and save the center point.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        LocationsMapCard(
                            region: Binding(
                                get: { viewModel.region },
                                set: { viewModel.region = $0 }
                            ),
                            places: viewModel.locationStore?.savedPlaces ?? [],
                            latestPins: [],
                            currentLocation: viewModel.currentLocation,
                            onUseMapCenter: {}
                        )
                        .frame(height: 280)
                        .listRowInsets(EdgeInsets())

                        Button {
                            syncCoordinatesFromMapCenter()
                            Task { await fillAddressFromMapCenter() }
                        } label: {
                            Label("Use map center", systemImage: "scope")
                        }
                    }
                }

                Section("Style") {
                    DisclosureGroup("Customize icon", isExpanded: $showStylePicker) {
                        OperationStylePicker(iconName: $iconName, colorHex: $iconColorHex)
                    }
                }
            }
            .navigationTitle("Add Place")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("common.save")
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .task {
                syncCoordinatesFromViewModel()
            }
        }
    }

    private func syncCoordinatesFromViewModel() {
        latitudeText = viewModel.latitudeText
        longitudeText = viewModel.longitudeText
    }

    private func syncCoordinatesFromMapCenter() {
        let coordinate = viewModel.mapCenterCoordinate()
        latitudeText = coordinate.latitude.formatted(.number.precision(.fractionLength(6)))
        longitudeText = coordinate.longitude.formatted(.number.precision(.fractionLength(6)))
    }

    private func resolveAddress() async {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isResolvingAddress = true
        defer { isResolvingAddress = false }
        if let coordinate = await viewModel.resolveAddress(trimmed) {
            latitudeText = coordinate.latitude.formatted(.number.precision(.fractionLength(6)))
            longitudeText = coordinate.longitude.formatted(.number.precision(.fractionLength(6)))
        }
    }

    private func fillAddressFromCurrentLocation() async {
        guard let coordinate = viewModel.currentCoordinate() else { return }
        if let resolved = await viewModel.reverseGeocode(coordinate: coordinate) {
            address = resolved
        }
    }

    private func fillAddressFromMapCenter() async {
        let coordinate = viewModel.mapCenterCoordinate()
        if let resolved = await viewModel.reverseGeocode(coordinate: coordinate) {
            address = resolved
        }
    }

    private func selectedCoordinate() -> CLLocationCoordinate2D? {
        switch method {
        case .address, .coordinates:
            let latitude = Double(latitudeText.replacingOccurrences(of: ",", with: "."))
            let longitude = Double(longitudeText.replacingOccurrences(of: ",", with: "."))
            guard let latitude, let longitude else { return nil }
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        case .currentLocation:
            return viewModel.currentCoordinate()
        case .mapCenter:
            return viewModel.mapCenterCoordinate()
        }
    }

    private func save() async {
        guard let coordinate = selectedCoordinate() else {
            viewModel.locationStore?.lastErrorMessage = "Invalid location input."
            Log.error("AddSavedPlaceSheet.save invalid coordinate. method=\(method.rawValue) title=\(title)")
            return
        }

        isSaving = true
        defer { isSaving = false }

        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        Log.msg("AddSavedPlaceSheet.save start title=\(title.trimmingCharacters(in: .whitespacesAndNewlines)) method=\(method.rawValue) lat=\(coordinate.latitude) lon=\(coordinate.longitude) selectedSpace=\(viewModel.locationStore?.currentSpaceId?.uuidString ?? "nil")")
        let didSave = await viewModel.locationStore?.addSavedPlace(
            name: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: trimmedDescription.isEmpty ? nil : trimmedDescription,
            category: category.rawValue,
            iconName: iconName.isEmpty ? nil : iconName,
            iconColorHex: iconColorHex,
            address: trimmedAddress.isEmpty ? nil : trimmedAddress,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radiusMeters: 100,
            actor: actorId
        ) ?? false
        Log.msg("AddSavedPlaceSheet.save finished title=\(title.trimmingCharacters(in: .whitespacesAndNewlines)) didSave=\(didSave) lastError=\(viewModel.locationStore?.lastErrorMessage ?? "nil")")
        if didSave {
            dismiss()
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

    return LocationsView()
        .environment(authRepo)
        .environment(spaceRepo)
        .modelContainer(container)
}
