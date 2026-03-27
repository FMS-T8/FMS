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
    public var notes: String?

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
        endLng: Double? = nil,
        notes: String? = nil
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
        self.notes = notes
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
        case notes
    }

    /// True when the break has been started but not yet ended.
    public var isOngoing: Bool {
        startTime != nil && endTime == nil
    }

    /// Human-readable duration, e.g. "12 min" or "1h 05m".
    public var formattedDuration: String {
        guard let minutes = durationMinutes else {
            // Compute live duration if still ongoing
            guard let start = startTime else { return "—" }
            let mins = Int(Date().timeIntervalSince(start) / 60)
            return mins < 60 ? "\(mins) min" : "\(mins / 60)h \(String(format: "%02d", mins % 60))m"
        }
        return minutes < 60 ? "\(minutes) min" : "\(minutes / 60)h \(String(format: "%02d", minutes % 60))m"
    }
}

public struct BreakLogInsert: Codable {
    public var id: String
    public var tripId: String?
    public var driverId: String?
    public var breakType: String?
    public var startTime: Date?
    public var endTime: Date?
    public var durationMinutes: Int?
    public var lat: Double?
    public var lng: Double?
    public var notes: String?

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
        notes: String? = nil
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
        self.notes = notes
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
        case notes
    }
}
