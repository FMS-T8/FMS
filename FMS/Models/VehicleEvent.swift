import Foundation

public enum EventType: String, Codable {
    case harshBraking = "HarshBraking"
    case rapidAcceleration = "RapidAcceleration"
    case maintenanceAlert = "MaintenanceAlert"
    case highGImpact = "HighGImpact"
}

public struct VehicleEvent: Codable, Identifiable {
    public var id: String
    public var vehicleID: String
    public var tripID: String?
    public var eventType: EventType
    public var timestamp: Date
    
    public init(id: String = UUID().uuidString, vehicleID: String, tripID: String? = nil, eventType: EventType, timestamp: Date = Date()) {
        self.id = id
        self.vehicleID = vehicleID
        self.tripID = tripID
        self.eventType = eventType
        self.timestamp = timestamp
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case vehicleID = "vehicle_id"
        case tripID = "trip_id"
        case eventType = "event_type"
        case timestamp
    }
}
