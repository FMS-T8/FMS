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
    
    public static var defaultIntervalMonths: Int {
        if let monthsStr = UserDefaults.standard.string(forKey: "fms_global_interval_months"), let months = Int(monthsStr) {
            return months
        }
        return 6
    }
    public static let upcomingThresholdPercentage: Double = 0.9 // 90% of interval
    public static let upcomingThresholdDays: Int = 15 // 15 days before month interval
    
    /// Calculates the maintenance status for a vehicle.
    public static func calculateStatus(for vehicle: Vehicle, defaultKm: Double? = nil, defaultMonths: Int? = nil) -> MaintenanceStatus {
        let intervalKm = vehicle.serviceIntervalKm ?? defaultKm ?? defaultIntervalKm
        let intervalMonths = vehicle.serviceIntervalMonths ?? defaultMonths ?? defaultIntervalMonths
        
        // 1. Odometer-based calculation
        let currentOdo = vehicle.odometer ?? 0
        let lastOdo = vehicle.lastServiceOdometer ?? 0
        let distanceSinceLast = currentOdo - lastOdo
        
        let odoStatus: MaintenanceStatus
        if distanceSinceLast >= intervalKm {
            odoStatus = .due
        } else if distanceSinceLast >= (intervalKm * upcomingThresholdPercentage) {
            odoStatus = .upcoming
        } else {
            odoStatus = .ok
        }
        
        // 2. Time-based calculation
        let lastDate = vehicle.lastServiceDate ?? vehicle.createdAt ?? Date()
        let calendar = Calendar.current
        guard let dueDate = calendar.date(byAdding: .month, value: intervalMonths, to: lastDate) else {
            return odoStatus
        }
        
        let daysUntilDue = calendar.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
        
        let timeStatus: MaintenanceStatus
        if Date() >= dueDate {
            timeStatus = .due
        } else if daysUntilDue <= upcomingThresholdDays {
            timeStatus = .upcoming
        } else {
            timeStatus = .ok
        }
        
        // Return the most critical status
        if odoStatus == .due || timeStatus == .due {
            return .due
        }
        if odoStatus == .upcoming || timeStatus == .upcoming {
            return .upcoming
        }
        return .ok
    }
    
    /// Returns a human-readable reason for the status.
    public static func getStatusReason(for vehicle: Vehicle, defaultKm: Double? = nil, defaultMonths: Int? = nil) -> String {
        let status = calculateStatus(for: vehicle, defaultKm: defaultKm, defaultMonths: defaultMonths)
        if status == .ok { return "Vehicle is in good condition." }
        
        let intervalKm = vehicle.serviceIntervalKm ?? defaultKm ?? defaultIntervalKm
        let intervalMonths = vehicle.serviceIntervalMonths ?? defaultMonths ?? defaultIntervalMonths
        let currentOdo = vehicle.odometer ?? 0
        let lastOdo = vehicle.lastServiceOdometer ?? 0
        let distanceSinceLast = currentOdo - lastOdo
        
        let lastDate = vehicle.lastServiceDate ?? vehicle.createdAt ?? Date()
        let calendar = Calendar.current
        let dueDate = calendar.date(byAdding: .month, value: intervalMonths, to: lastDate) ?? Date()
        
        if distanceSinceLast >= intervalKm {
            return "Mileage limit reached (\(Int(distanceSinceLast)) / \(Int(intervalKm)) km)."
        }
        
        if Date() >= dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "Time limit reached (Due since \(formatter.string(from: dueDate)))."
        }
        
        if distanceSinceLast >= (intervalKm * upcomingThresholdPercentage) {
            return "Approaching mileage limit (\(Int(distanceSinceLast)) km)."
        }
        
        return "Approaching time limit."
    }
}
