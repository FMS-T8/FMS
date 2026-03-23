import Foundation

public enum MaintenanceStatus: String, CaseIterable, Codable {
    case ok = "OK"
    case upcoming = "UPCOMING"
    case due = "DUE"
    
    public var colorName: String {
        switch self {
        case .ok:       return "alertGreen"
        case .upcoming: return "alertOrange"
        case .due:      return "alertRed"
        }
    }
}

public struct MaintenancePredictionService {
    
    // Default intervals if not specified in vehicle
    public static var defaultIntervalKm: Double {
        if let kmStr = UserDefaults.standard.string(forKey: "fms_global_interval_km"), let km = Double(kmStr) {
            return km
        }
        return 10000.0
    }
    
    public static let upcomingThresholdPercentage: Double = 0.9 // 90% of interval
    
    /// Calculates the maintenance status for a vehicle.
    public static func calculateStatus(for vehicle: Vehicle, defaultKm: Double? = nil) -> MaintenanceStatus {
        let rawIntervalKm = vehicle.serviceIntervalKm ?? defaultKm ?? defaultIntervalKm
        
        // Ensure intervals are positive to avoid division by zero or negative logic
        let intervalKm = max(rawIntervalKm, 1.0)
        
        // Odometer-based calculation
        let currentOdo = vehicle.odometer ?? 0
        let lastOdo = vehicle.lastServiceOdometer ?? 0
        let distanceSinceLast = currentOdo - lastOdo
        
        if distanceSinceLast >= intervalKm {
            return .due
        } else if distanceSinceLast >= (intervalKm * upcomingThresholdPercentage) {
            return .upcoming
        } else {
            return .ok
        }
    }
    
    /// Returns a human-readable reason for the status.
    public static func getStatusReason(for vehicle: Vehicle, defaultKm: Double? = nil) -> String {
        let status = calculateStatus(for: vehicle, defaultKm: defaultKm)
        if status == .ok { return "Vehicle is in good condition." }
        
        let rawIntervalKm = vehicle.serviceIntervalKm ?? defaultKm ?? defaultIntervalKm
        let intervalKm = max(rawIntervalKm, 1.0)
        let currentOdo = vehicle.odometer ?? 0
        let lastOdo = vehicle.lastServiceOdometer ?? 0
        let distanceSinceLast = currentOdo - lastOdo
        
        if distanceSinceLast >= intervalKm {
            return "Mileage limit reached (\(Int(distanceSinceLast)) / \(Int(intervalKm)) km)."
        }
        
        if distanceSinceLast >= (intervalKm * upcomingThresholdPercentage) {
            return "Approaching mileage limit (\(Int(distanceSinceLast)) km)."
        }
        
        return "Service required."
    }
}
