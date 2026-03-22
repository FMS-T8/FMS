import Foundation

public struct BreakLog: Codable, Identifiable {
    public var id: String
    public var tripId: String?
    public var driverId: String?
    public var breakType: String?
    public var startTime: Date?
    public var endTime: Date?
    public var durationMinutes: Int?
    public var lat: Double?
    public var lng: Double?
    public var endLat: Double?
    public var endLng: Double?

    public init(
        id: String = UUID().uuidString,
        tripId: String? = nil,
        driverId: String? = nil,
        breakType: String? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        durationMinutes: Int? = nil,
        lat: Double? = nil,
        lng: Double? = nil,
        endLat: Double? = nil,
        endLng: Double? = nil
    ) {
        self.id = id
        self.tripId = tripId
        self.driverId = driverId
        self.breakType = breakType
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes
        self.lat = lat
        self.lng = lng
        self.endLat = endLat
        self.endLng = endLng
    }

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case driverId = "driver_id"
        case breakType = "break_type"
        case startTime = "start_time"
        case endTime = "end_time"
        case durationMinutes = "duration_minutes"
        case lat
        case lng
        case endLat = "end_lat"
        case endLng = "end_lng"
    }
}

public struct BreakLogInsert: Codable {
    public var tripId: String?
    public var driverId: String?
    public var breakType: String?
    public var startTime: Date?
    public var endTime: Date?
    public var durationMinutes: Int?
    public var lat: Double?
    public var lng: Double?
    public var endLat: Double?
    public var endLng: Double?

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case driverId = "driver_id"
        case breakType = "break_type"
        case startTime = "start_time"
        case endTime = "end_time"
        case durationMinutes = "duration_minutes"
        case lat
        case lng
        case endLat = "end_lat"
        case endLng = "end_lng"
    }
}
