import Foundation

/// Maps the `vehicle_fuel_efficiency` Supabase view.
public struct VehicleFuelEfficiency: Decodable, Identifiable {
    public var id: String { vehicleId }
    public let vehicleId: String
    public let plateNumber: String
    public let totalTrips: Int
    public let kmPerLiter: Double

    enum CodingKeys: String, CodingKey {
        case vehicleId = "vehicle_id"
        case plateNumber = "plate_number"
        case totalTrips = "total_trips"
        case kmPerLiter = "km_per_liter"
    }

    /// Color tier based on efficiency value.
    public enum EfficiencyTier {
        case good, moderate, poor

        public init(kmPerLiter: Double) {
            if kmPerLiter >= 10 { self = .good }
            else if kmPerLiter >= 7 { self = .moderate }
            else { self = .poor }
        }
    }

    public var tier: EfficiencyTier { .init(kmPerLiter: kmPerLiter) }
}
