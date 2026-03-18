import Foundation
import CoreLocation
import MapKit
import SwiftData

@MainActor
@Observable
final class LocationViewModel {
    var region: MapKit.MKCoordinateRegion
    var latitudeText: String
    var longitudeText: String
    var currentLocation: CoreLocation.CLLocation?
    var isFollowingUser: Bool = true
    var locationStore: LocationStore?
    var locationErrorMessage: String?

    private let locationManager = LocationManager()
    private let geocoder = CLGeocoder()
    private var modelContext: ModelContext?
    private var observedCheckInIDs: Set<UUID> = []
    private var lastNearbySuggestionPlaceId: UUID?
    private var lastNearbySuggestionAt: Date?

    init() {
        let initialCoord = CoreLocation.CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122)
        region = MapKit.MKCoordinateRegion(
            center: initialCoord,
            span: MapKit.MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )
        latitudeText = Self.formatCoordinate(initialCoord.latitude)
        longitudeText = Self.formatCoordinate(initialCoord.longitude)

        locationManager.onLocationUpdate = { [weak self] location in
            guard let self else { return }
            self.applyCurrentLocation(location)
        }
    }

    /// Sets dependencies, initializes store and starts location updates.
    func setup(modelContext: ModelContext, spaceRepo: SpaceRepository, isPreview: Bool) async {
        self.modelContext = modelContext

        if locationStore == nil {
            let repo = LocationRepository(client: SupabaseConfig.client, context: modelContext)
            let store = LocationStore(modelContext: modelContext, repository: repo)
            locationStore = store
            store.setSpace(spaceRepo.selectedSpace?.id)
            if !isPreview {
                await store.refreshRemote()
            }
        }

        observedCheckInIDs = Set(locationStore?.checkIns.map(\.id) ?? [])

        locationManager.startTracking()
        locationErrorMessage = locationManager.lastErrorMessage
        if let location = locationManager.lastLocation {
            applyCurrentLocation(location)
        }
    }

    /// Handles selected space change.
    func handleSpaceChange(_ newSpaceId: UUID?) async {
        locationStore?.setSpace(newSpaceId)
        observedCheckInIDs = Set(locationStore?.checkIns.map(\.id) ?? [])
        lastNearbySuggestionPlaceId = nil
        lastNearbySuggestionAt = nil
        if newSpaceId != nil {
            await locationStore?.refreshRemote()
            observedCheckInIDs = Set(locationStore?.checkIns.map(\.id) ?? [])
        }
    }

    /// Requests fresh GPS location from system.
    func requestFreshLocation() {
        locationManager.requestCurrentLocation()
        locationErrorMessage = locationManager.lastErrorMessage
    }

    func currentCoordinate() -> CLLocationCoordinate2D? {
        currentLocation?.coordinate
    }

    func mapCenterCoordinate() -> CLLocationCoordinate2D {
        region.center
    }

    func useMapCenterForInput() {
        latitudeText = Self.formatCoordinate(region.center.latitude)
        longitudeText = Self.formatCoordinate(region.center.longitude)
        isFollowingUser = false
    }

    func resolveAddress(_ address: String) async -> CLLocationCoordinate2D? {
        do {
            let matches = try await geocoder.geocodeAddressString(address)
            guard let coordinate = matches.first?.location?.coordinate else {
                locationErrorMessage = "Address could not be found."
                return nil
            }
            latitudeText = Self.formatCoordinate(coordinate.latitude)
            longitudeText = Self.formatCoordinate(coordinate.longitude)
            centerMap(on: coordinate)
            locationErrorMessage = nil
            return coordinate
        } catch {
            locationErrorMessage = "Address lookup failed: \(error.localizedDescription)"
            return nil
        }
    }

    func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> String? {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
            guard let placemark = placemarks.first else { return nil }
            let parts = [
                placemark.name,
                placemark.locality,
                placemark.administrativeArea,
                placemark.country
            ]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            return parts.joined(separator: ", ")
        } catch {
            return nil
        }
    }

    /// Uses current device location as text input and centers map.
    func useCurrentLocationForInput() {
        guard let location = locationManager.lastLocation else {
            requestFreshLocation()
            locationErrorMessage = String(localized: "locations.error.waitingForCurrent")
            return
        }
        applyCurrentLocation(location)
    }

    /// Parses text inputs to coordinate used by map and save action.
    func parsedInputCoordinate() -> CoreLocation.CLLocationCoordinate2D? {
        guard
            let latitude = Double(latitudeText.replacingOccurrences(of: ",", with: ".")),
            let longitude = Double(longitudeText.replacingOccurrences(of: ",", with: "."))
        else {
            return nil
        }
        return CoreLocation.CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Moves camera to the latest ping in the selected space.
    func centerOnLatestPin() {
        guard let latest = locationStore?.pings.first else { return }
        centerMap(on: CoreLocation.CLLocationCoordinate2D(latitude: latest.latitude, longitude: latest.longitude))
    }

    func suggestedCheckInPlace(for userId: UUID?) -> SavedPlace? {
        guard
            let userId,
            let currentLocation,
            let locationStore
        else {
            return nil
        }

        let nearbyPlaces = locationStore.savedPlaces
            .compactMap { place -> (SavedPlace, CLLocationDistance)? in
                let distance = currentLocation.distance(
                    from: CLLocation(latitude: place.latitude, longitude: place.longitude)
                )
                guard distance <= max(place.radiusMeters, 50) else { return nil }
                return (place, distance)
            }
            .sorted { $0.1 < $1.1 }

        guard let place = nearbyPlaces.first?.0 else {
            return nil
        }

        guard !hasRecentCheckIn(userId: userId, placeId: place.id, within: 30 * 60) else {
            return nil
        }

        return place
    }

    func consumeNearbyCheckInSuggestion(for userId: UUID?, notificationStore: AppNotificationStore) {
        guard let place = suggestedCheckInPlace(for: userId) else {
            lastNearbySuggestionPlaceId = nil
            return
        }

        if
            lastNearbySuggestionPlaceId == place.id,
            let lastNearbySuggestionAt,
            Date.now.timeIntervalSince(lastNearbySuggestionAt) < 20 * 60
        {
            return
        }

        lastNearbySuggestionPlaceId = place.id
        lastNearbySuggestionAt = .now

        notificationStore.addNotification(
            title: place.resolvedCategory.proximityPromptTitle,
            body: "Jesteś blisko miejsca \(place.name). Możesz zrobić check-in jednym tapnięciem.",
            category: .alert,
            priority: .normal,
            source: "location-nearby-\(place.id.uuidString)",
            toast: AppToast(
                title: "Możesz zrobić check-in",
                message: place.name,
                style: .info
            )
        )
    }

    func consumeNewCheckIns(currentUserId: UUID?, notificationStore: AppNotificationStore) {
        guard let locationStore else { return }

        let newCheckIns = locationStore.checkIns.filter { !observedCheckInIDs.contains($0.id) }
        observedCheckInIDs.formUnion(locationStore.checkIns.map(\.id))

        for checkIn in newCheckIns {
            guard checkIn.userId != currentUserId else { continue }

            let savedPlace = locationStore.savedPlaces.first(where: { $0.id == checkIn.placeId })
            let placeName = checkIn.placeName ?? savedPlace?.name ?? "zapisane miejsce"
            let category = savedPlace?.resolvedCategory ?? .other

            notificationStore.addNotification(
                title: "Nowy check-in",
                body: "\(checkIn.userDisplayName) \(category.arrivalMessagePrefix): \(placeName).",
                category: .info,
                priority: .normal,
                source: "location-checkin-\(checkIn.id.uuidString)",
                toast: AppToast(
                    title: "Nowy check-in",
                    message: "\(checkIn.userDisplayName) • \(placeName)",
                    style: .info
                )
            )
        }
    }

    /// Stops location updates when view disappears.
    func stopTracking() {
        locationManager.stopTracking()
    }

    /// Applies new device location to state and map.
    private func applyCurrentLocation(_ location: CoreLocation.CLLocation) {
        currentLocation = location
        latitudeText = Self.formatCoordinate(location.coordinate.latitude)
        longitudeText = Self.formatCoordinate(location.coordinate.longitude)
        locationErrorMessage = nil
        if isFollowingUser {
            centerMap(on: location.coordinate)
        }
    }

    /// Centers map camera on chosen coordinate.
    private func centerMap(on coordinate: CoreLocation.CLLocationCoordinate2D) {
        region.center = coordinate
    }

    private func hasRecentCheckIn(userId: UUID, placeId: UUID, within interval: TimeInterval) -> Bool {
        guard let locationStore else { return false }

        return locationStore.checkIns.contains { checkIn in
            checkIn.userId == userId
                && checkIn.placeId == placeId
                && Date.now.timeIntervalSince(checkIn.checkedInAt) < interval
        }
    }

    /// Formats coordinates for text fields.
    private static func formatCoordinate(_ value: Double) -> String {
        String(format: "%.6f", value)
    }
}
