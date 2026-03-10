import Foundation

public struct Geofence: Codable, Identifiable {
    public var id: String
    public var name: String?
    public var centerLat: Double?
    public var centerLng: Double?
    public var radiusMeters: Int?
    public var createdBy: String?
    public var createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case centerLat = "center_lat"
        case centerLng = "center_lng"
        case radiusMeters = "radius_meters"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}
