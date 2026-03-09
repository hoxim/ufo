import CoreLocation

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
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

    /// Starts tracking user location with proper authorization handling.
    func startTracking() {
#if os(macOS)
        switch manager.authorizationStatus {
        case .authorizedAlways:
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
#else
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
#endif
    }

    /// Requests one fresh location update.
    func requestCurrentLocation() {
        if isAuthorized(manager.authorizationStatus) {
            manager.requestLocation()
        } else {
            startTracking()
        }
    }

    /// Stops continuous updates.
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
#if os(macOS)
        return status == .authorizedAlways
#else
        return status == .authorizedAlways || status == .authorizedWhenInUse
#endif
    }
}
