#if os(iOS)

import CoreLocation
import Foundation
import MapKit
import SwiftData
import SwiftUI


@MainActor
@Observable
final class PhoneLocationViewModel {
    var region: MKCoordinateRegion
    var latitudeText: String
    var longitudeText: String
    var currentLocation: CLLocation?
    var isFollowingUser: Bool = true
    var locationStore: LocationStore?
    var locationErrorMessage: String?

    private let locationManager = PhoneLocationManager()
    private var modelContext: ModelContext?
    private var observedCheckInIDs: Set<UUID> = []
    private var lastNearbySuggestionPlaceId: UUID?
    private var lastNearbySuggestionAt: Date?

    init() {
        let initialCoord = CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122)
        region = MKCoordinateRegion(
            center: initialCoord,
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )
        latitudeText = Self.formatCoordinate(initialCoord.latitude)
        longitudeText = Self.formatCoordinate(initialCoord.longitude)

        locationManager.onLocationUpdate = { [weak self] location in
            guard let self else { return }
            self.applyCurrentLocation(location)
        }
    }

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
            guard let request = MKGeocodingRequest(addressString: address) else {
                locationErrorMessage = "Address could not be found."
                return nil
            }
            let matches = try await request.mapItems
            guard let coordinate = matches.first?.location.coordinate else {
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
            guard let request = MKReverseGeocodingRequest(
                location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            ) else {
                return nil
            }

            let mapItems = try await request.mapItems
            guard let mapItem = mapItems.first else { return nil }

            if let fullAddress = mapItem.addressRepresentations?.fullAddress(includingRegion: true, singleLine: true),
               !fullAddress.isEmpty {
                return fullAddress
            }

            if let fullAddress = mapItem.address?.fullAddress, !fullAddress.isEmpty {
                return fullAddress
            }

            if let shortAddress = mapItem.address?.shortAddress, !shortAddress.isEmpty {
                return shortAddress
            }

            if let cityWithContext = mapItem.addressRepresentations?.cityWithContext, !cityWithContext.isEmpty {
                return cityWithContext
            }

            if let name = mapItem.name, !name.isEmpty {
                return name
            }

            return nil
        } catch {
            return nil
        }
    }

    func useCurrentLocationForInput() {
        guard let location = locationManager.lastLocation else {
            requestFreshLocation()
            locationErrorMessage = String(localized: "locations.error.waitingForCurrent")
            return
        }
        applyCurrentLocation(location)
    }

    func parsedInputCoordinate() -> CLLocationCoordinate2D? {
        guard
            let latitude = Double(latitudeText.replacingOccurrences(of: ",", with: ".")),
            let longitude = Double(longitudeText.replacingOccurrences(of: ",", with: "."))
        else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func centerOnLatestPin() {
        guard let latest = locationStore?.pings.first else { return }
        centerMap(on: CLLocationCoordinate2D(latitude: latest.latitude, longitude: latest.longitude))
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

    func stopTracking() {
        locationManager.stopTracking()
    }

    private func applyCurrentLocation(_ location: CLLocation) {
        currentLocation = location
        latitudeText = Self.formatCoordinate(location.coordinate.latitude)
        longitudeText = Self.formatCoordinate(location.coordinate.longitude)
        locationErrorMessage = nil
        if isFollowingUser {
            centerMap(on: location.coordinate)
        }
    }

    private func centerMap(on coordinate: CLLocationCoordinate2D) {
        region.center = coordinate
    }

    private func hasRecentCheckIn(userId: UUID, placeId: UUID, within interval: TimeInterval) -> Bool {
        guard let locationStore else { return false }

        return locationStore.checkIns.contains { checkIn in
            checkIn.userId == userId &&
            checkIn.placeId == placeId &&
            Date.now.timeIntervalSince(checkIn.checkedInAt) < interval
        }
    }

    private static func formatCoordinate(_ value: Double) -> String {
        String(format: "%.6f", value)
    }
}


final class PhoneLocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    var authorizationStatus: CLAuthorizationStatus
    var lastLocation: CLLocation?
    var lastErrorMessage: String?
    var onLocationUpdate: ((CLLocation) -> Void)?

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
    }

    func startTracking() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
            manager.requestLocation()
            lastErrorMessage = nil
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            lastErrorMessage = String(localized: "locations.error.permissionDenied")
        @unknown default:
            break
        }
    }

    func requestCurrentLocation() {
        if isAuthorized(manager.authorizationStatus) {
            manager.requestLocation()
        } else {
            startTracking()
        }
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        startTracking()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastLocation = location
        lastErrorMessage = nil
        onLocationUpdate?(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastErrorMessage = "\(String(localized: "locations.error.prefix")) \(error.localizedDescription)"
    }

    private func isAuthorized(_ status: CLAuthorizationStatus) -> Bool {
        status == .authorizedAlways || status == .authorizedWhenInUse
    }
}

#endif
