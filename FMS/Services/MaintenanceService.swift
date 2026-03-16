import Foundation

/// Service responsible for assessing vehicle maintenance needs.
public final class MaintenanceService {
    public static let shared = MaintenanceService()
    
    private init() {}
    
    /// Checks if a vehicle is approaching or has exceeded its scheduled maintenance interval.
    ///
    /// - Parameters:
    ///   - vehicle: The vehicle to evaluate for maintenance.
    ///   - interval: The configured distance (e.g., in kilometers) between required maintenance.
    ///   - warningThreshold: Distance before the interval at which a warning should be triggered.
    /// - Returns: `true` if the vehicle requires or is approaching maintenance.
    public func isMaintenanceDue(
        vehicle: Vehicle,
        interval: Double = 10000.0,
        warningThreshold: Double = 500.0
    ) -> Bool {
        guard let currentOdometer = vehicle.odometer else {
            return false // Without odometer data, we cannot predict maintenance.
        }
        
        let remainder = currentOdometer.truncatingRemainder(dividingBy: interval)
        let distanceToNextService = interval - remainder
        
        // Return true if it's very close or overdue based on the remainder calculation
        return distanceToNextService <= warningThreshold || currentOdometer >= interval
    }
    
    /// Checks if a vehicle has exceeded its scheduled maintenance interval without service.
    ///
    /// - Parameters:
    ///   - vehicle: The vehicle to evaluate for overdue maintenance.
    ///   - interval: The configured distance between required maintenance.
    /// - Returns: `true` if the vehicle is strictly overdue.
    public func isMaintenanceOverdue(
        vehicle: Vehicle,
        interval: Double = 10000.0
    ) -> Bool {
        guard let currentOdometer = vehicle.odometer else { return false }
        
        let remainder = currentOdometer.truncatingRemainder(dividingBy: interval)
        // If the odometer is exactly a multiple, or past it and hasn't been reset (logic simplified here)
        // A true implementation would check the difference between current odometer and 'last service odometer'.
        // For simplicity, we check if current distance pushes past the threshold.
        return currentOdometer >= interval && remainder > 0.0 // Indicative of exceeded threshold
    }
}
