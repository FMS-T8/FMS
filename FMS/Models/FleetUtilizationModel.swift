import Foundation

/// Maps the `fleet_utilization` Supabase view.
public struct FleetUtilization: Decodable, Identifiable {
    public var id: String { vehicleId }
    public let vehicleId: String
    public let plateNumber: String
    public let utilizationPercent: Double
    public let availableHours: Double
    public let activeHours: Double

    enum CodingKeys: String, CodingKey {
        case vehicleId = "vehicle_id"
        case plateNumber = "plate_number"
        case utilizationPercent = "utilization_percent"
        case availableHours = "available_hours"
        case activeHours = "active_hours"
    }

    /// Color tier based on utilization percentage.
    public enum UtilizationTier {
        case high, medium, low

        public init(percent: Double) {
            if percent >= 70 { self = .high }
            else if percent >= 40 { self = .medium }
            else { self = .low }
        }
    }

    public var tier: UtilizationTier { .init(percent: utilizationPercent) }
}
