import Foundation

// MARK: - SOS Alert Status

public enum SOSAlertStatus: String, Codable {
    case active
    case acknowledged
    case resolved
    case cancelled
}

// MARK: - SOS Alert

public struct SOSAlert: Codable, Identifiable {
    public var id: String
    public var driverId: String
    public var vehicleId: String
    public var tripId: String?
    public var latitude: Double
    public var longitude: Double
    public var speed: Double?
    public var timestamp: Date
    public var status: SOSAlertStatus
    public var acknowledgedAt: Date?
    public var resolvedAt: Date?

    public init(
        id: String = UUID().uuidString,
        driverId: String,
        vehicleId: String,
        tripId: String? = nil,
        latitude: Double,
        longitude: Double,
        speed: Double? = nil,
        timestamp: Date = Date(),
        status: SOSAlertStatus = .active,
        acknowledgedAt: Date? = nil,
        resolvedAt: Date? = nil
    ) {
        self.id = id
        self.driverId = driverId
        self.vehicleId = vehicleId
        self.tripId = tripId
        self.latitude = latitude
        self.longitude = longitude
        self.speed = speed
        self.timestamp = timestamp
        self.status = status
        self.acknowledgedAt = acknowledgedAt
        self.resolvedAt = resolvedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case driverId = "driver_id"
        case vehicleId = "vehicle_id"
        case tripId = "trip_id"
        case latitude
        case longitude
        case speed
        case timestamp
        case status
        case acknowledgedAt = "acknowledged_at"
        case resolvedAt = "resolved_at"
    }
}

// MARK: - SOS Alert Insert

public struct SOSAlertInsert: Codable {
    public var id: String
    public var driverId: String
    public var vehicleId: String
    public var tripId: String?
    public var latitude: Double
    public var longitude: Double
    public var speed: Double?
    public var timestamp: Date
    public var status: SOSAlertStatus

    public init(
        id: String = UUID().uuidString,
        driverId: String,
        vehicleId: String,
        tripId: String? = nil,
        latitude: Double,
        longitude: Double,
        speed: Double? = nil,
        timestamp: Date = Date(),
        status: SOSAlertStatus = .active
    ) {
        self.id = id
        self.driverId = driverId
        self.vehicleId = vehicleId
        self.tripId = tripId
        self.latitude = latitude
        self.longitude = longitude
        self.speed = speed
        self.timestamp = timestamp
        self.status = status
    }

    enum CodingKeys: String, CodingKey {
        case id
        case driverId = "driver_id"
        case vehicleId = "vehicle_id"
        case tripId = "trip_id"
        case latitude
        case longitude
        case speed
        case timestamp
        case status
    }
}
