import Foundation
import PostgREST
import Supabase

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
    
    public static let upcomingThresholdPercentage: Double = 0.8 // 80% of interval
    
    /// Calculates the maintenance status for a vehicle.
    public static func calculateStatus(for vehicle: Vehicle, defaultKm: Double? = nil) -> MaintenanceStatus {
        let intervalKm = max(vehicle.effectiveServiceIntervalKm, 1.0)
        
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
    
    public struct MaintenanceForecast: Codable {
        public let projectedDate: Date?
        public let avgDailyKm: Double
        public let daysRemaining: Int?
        public let isHighUsage: Bool
    }
    
    /// Calculates a maintenance forecast based on recent usage patterns.
    public static func calculateForecast(for vehicle: Vehicle, defaultKm: Double? = nil) async -> MaintenanceForecast {
        let intervalKm = max(vehicle.effectiveServiceIntervalKm, 1.0)
        
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        do {
            let trips: [Trip] = try await SupabaseService.shared.client
                .from("trips")
                .select("id, distance_km")
                .eq("vehicle_id", value: vehicle.id)
                .gte("start_time", value: thirtyDaysAgo)
                .execute()
                .value
            
            let totalKm = trips.reduce(0) { $0 + ($1.distanceKm ?? 0) }
            let avgDailyKm = totalKm / 30.0
            
            return projectForecast(for: vehicle, avgDailyKm: avgDailyKm, intervalKm: intervalKm)
        } catch is CancellationError {
            return MaintenanceForecast(projectedDate: nil, avgDailyKm: 0, daysRemaining: nil, isHighUsage: false)
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == -999 {
            return MaintenanceForecast(projectedDate: nil, avgDailyKm: 0, daysRemaining: nil, isHighUsage: false)
        } catch {
            print("[MaintenancePredictionService] Forecast Error: \(error)")
            return MaintenanceForecast(projectedDate: nil, avgDailyKm: 0, daysRemaining: nil, isHighUsage: false)
        }
    }
    
    /// Synchronously projects a forecast given a daily usage rate and interval.
    /// This allows for instant UI updates when global settings change.
    public static func projectForecast(for vehicle: Vehicle, avgDailyKm: Double, intervalKm: Double) -> MaintenanceForecast {
        let currentOdo = vehicle.odometer ?? 0
        let lastOdo = vehicle.lastServiceOdometer ?? 0
        let distanceSinceLast = currentOdo - lastOdo
        let kmRemaining = intervalKm - distanceSinceLast
        
        if avgDailyKm > 0 {
            let daysRemaining = Int(kmRemaining / avgDailyKm)
            let projectedDate = Calendar.current.date(byAdding: .day, value: daysRemaining, to: Date())
            
            return MaintenanceForecast(
                projectedDate: projectedDate,
                avgDailyKm: avgDailyKm,
                daysRemaining: daysRemaining,
                isHighUsage: avgDailyKm > (intervalKm / 30.0)
            )
        } else {
            let isDue = distanceSinceLast >= intervalKm
            return MaintenanceForecast(
                projectedDate: isDue ? Date() : nil,
                avgDailyKm: 0,
                daysRemaining: isDue ? 0 : nil,
                isHighUsage: false
            )
        }
    }
    
    /// Returns a human-readable reason for the status.
    public static func getStatusReason(for vehicle: Vehicle, defaultKm: Double? = nil) -> String {
        let status = calculateStatus(for: vehicle, defaultKm: defaultKm)
        if status == .ok { return "Vehicle is in good condition." }
        
        let intervalKm = max(vehicle.effectiveServiceIntervalKm, 1.0)
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
