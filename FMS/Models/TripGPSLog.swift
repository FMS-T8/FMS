import Foundation

public struct TripGPSLog: Codable, Identifiable {
    public var id: String
    public var tripId: String?
    public var lat: Double?
    public var lng: Double?
    public var speed: Double?
    public var heading: Double?
    public var recordedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case lat
        case lng
        case speed
        case heading
        case recordedAt = "recorded_at"
    }
}
