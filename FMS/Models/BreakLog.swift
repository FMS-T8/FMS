import Foundation

public struct BreakLog: Codable, Identifiable {
    public var id: String
    public var tripId: String?
    public var driverId: String?
    public var startTime: Date?
    public var endTime: Date?
    public var durationMinutes: Int?
    public var lat: Double?
    public var lng: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case driverId = "driver_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case durationMinutes = "duration_minutes"
        case lat
        case lng
    }
}
