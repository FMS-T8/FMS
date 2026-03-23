import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
public final class LocationManager: NSObject {
    public private(set) var currentLocation: CLLocation?
    public private(set) var authorizationStatus: CLAuthorizationStatus
    public private(set) var lastError: Error?
    
    private var locationContinuation: AsyncStream<CLLocation>.Continuation?

    private let manager: CLLocationManager

    public override init() {
        self.manager = CLLocationManager()
        self.authorizationStatus = manager.authorizationStatus
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 10
        manager.pausesLocationUpdatesAutomatically = false
        manager.activityType = .automotiveNavigation
        #if !targetEnvironment(simulator)
        let backgroundModes = Bundle.main.infoDictionary?["UIBackgroundModes"] as? [String] ?? []
        if backgroundModes.contains("location") {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        } else {
            print("[LocationManager] ⚠️ UIBackgroundModes does not contain 'location' — background tracking disabled.")
        }
        #endif
    }

    public var isAuthorizedForTrip: Bool {
        authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse
    }

    public var isPermissionDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    public func requestAlwaysPermission() {
        manager.requestAlwaysAuthorization()
    }

    public func requestWhenInUsePermission() {
        manager.requestWhenInUseAuthorization()
    }

    public func startUpdating() {
        guard isAuthorizedForTrip else {
            print("[LocationManager] ⚠️ startUpdating called but not authorized (status=\(authorizationStatus.rawValue))")
            return
        }
        print("[LocationManager] ▶️ startUpdatingLocation")
        manager.startUpdatingLocation()
    }

    public func stopUpdating() {
        print("[LocationManager] ⏹️ stopUpdatingLocation")
        manager.stopUpdatingLocation()
    }

    /// Provides an asynchronous stream of location updates.
    /// Each call creates a new stream that receives all future updates from this manager.
    public func locationUpdates() -> AsyncStream<CLLocation> {
        AsyncStream { continuation in
            locationContinuation = continuation
            continuation.onTermination = { @Sendable _ in
                // Standard Observation doesn't strictly need this, but good practice
            }
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        print("[LocationManager] 🔑 Authorization changed to: \(authorizationStatus.rawValue) (\(authorizationDescription))")

        if authorizationStatus == .authorizedWhenInUse {
            manager.requestAlwaysAuthorization()
        }

        if isAuthorizedForTrip {
            print("[LocationManager] ✅ Authorized — auto-starting location updates")
            manager.startUpdatingLocation()
        } else if isPermissionDenied {
            print("[LocationManager] ❌ Permission denied — stopping location updates")
            manager.stopUpdatingLocation()
        }
    }

    private var authorizationDescription: String {
        switch authorizationStatus {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorizedWhenInUse: return "whenInUse"
        case .authorizedAlways: return "always"
        @unknown default: return "unknown"
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        locationContinuation?.yield(location)
        #if DEBUG
        print("[LocationManager] 📍 Location update: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        #endif
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastError = error
    }
}
