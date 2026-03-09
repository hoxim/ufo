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
    private var modelContext: ModelContext?

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

        locationManager.startTracking()
        locationErrorMessage = locationManager.lastErrorMessage
        if let location = locationManager.lastLocation {
            applyCurrentLocation(location)
        }
    }

    /// Handles selected space change.
    func handleSpaceChange(_ newSpaceId: UUID?) async {
        locationStore?.setSpace(newSpaceId)
        if newSpaceId != nil {
            await locationStore?.refreshRemote()
        }
    }

    /// Requests fresh GPS location from system.
    func requestFreshLocation() {
        locationManager.requestCurrentLocation()
        locationErrorMessage = locationManager.lastErrorMessage
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

    /// Formats coordinates for text fields.
    private static func formatCoordinate(_ value: Double) -> String {
        String(format: "%.6f", value)
    }
}
