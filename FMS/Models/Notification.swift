import Foundation

public struct Notification: Codable, Identifiable {
    public var id: String
    public var recipientId: String?
    public var type: String?
    public var vehicleId: String?
    public var tripId: String?
    public var message: String?
    public var isRead: Bool?
    public var createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case recipientId = "recipient_id"
        case type
        case vehicleId = "vehicle_id"
        case tripId = "trip_id"
        case message
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}
