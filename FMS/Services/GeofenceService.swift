import Foundation
import CoreLocation

/// Service responsible for managing geofence checks and boundary logic.
public final class GeofenceService {
    public static let shared = GeofenceService()
    
    private init() {}
    
    /// Calculates the distance between the vehicle's location and the center of the geofence.
    /// Returns `true` if the vehicle's distance exceeds the allowed radius.
    public func isBreaching(location: CLLocationCoordinate2D, geofence: Geofence) -> Bool {
        guard let centerLat = geofence.centerLat,
              let centerLng = geofence.centerLng,
              let radiusMeters = geofence.radiusMeters,
              radiusMeters > 0 else {
            return false // Invalid geofence data, cannot calculate breach
        }
        
        let geofenceLocation = CLLocation(latitude: centerLat, longitude: centerLng)
        let vehicleLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        // Distance in meters
        let distance = vehicleLocation.distance(from: geofenceLocation)
        
        return distance > Double(radiusMeters)
    }
}
