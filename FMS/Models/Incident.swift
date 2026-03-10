import Foundation

public struct Incident: Codable, Identifiable {
    public var id: String
    public var tripId: String?
    public var vehicleId: String?
    public var driverId: String?
    public var severity: String?
    public var lat: Double?
    public var lng: Double?
    public var speedBefore: Double?
    public var speedAfter: Double?
    public var createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case vehicleId = "vehicle_id"
        case driverId = "driver_id"
        case severity
        case lat
        case lng
        case speedBefore = "speed_before"
        case speedAfter = "speed_after"
        case createdAt = "created_at"
    }
}
