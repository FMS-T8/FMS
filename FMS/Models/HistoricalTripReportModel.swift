import Foundation

/// Decoded from a Supabase `.select()` on `trips` that joins
/// `vehicles(plate_number)` and `users(name)`.
public struct HistoricalTripReport: Decodable, Identifiable {
    public let id: String
    public let startTime: Date?
    public let distanceKm: Double?
    public let fuelUsedLiters: Double?
    public let vehicles: VehicleRef?
    public let users: DriverRef?

    enum CodingKeys: String, CodingKey {
        case id
        case startTime = "start_time"
        case distanceKm = "distance_km"
        case fuelUsedLiters = "fuel_used_liters"
        case vehicles
        case users
    }

    // MARK: - Nested join structs

    public struct VehicleRef: Decodable {
        public let plateNumber: String

        enum CodingKeys: String, CodingKey {
            case plateNumber = "plate_number"
        }
    }

    public struct DriverRef: Decodable {
        public let name: String
    }

    // MARK: - Convenience accessors

    public var plateNumber: String { vehicles?.plateNumber ?? "—" }
    public var driverName: String { users?.name ?? "—" }
}
