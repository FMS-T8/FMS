import Foundation

// Assuming image_urls comes back as an array of strings natively in JSON or as data. We will map to [String]? for JSON compatibility.
public struct VehicleInspection: Codable, Identifiable {
    public var id: String
    public var vehicleId: String?
    public var driverId: String?
    public var inspectionType: String?
    public var brakesOk: Bool?
    public var tiresOk: Bool?
    public var headlightsOk: Bool?
    public var mirrorsOk: Bool?
    public var engineOk: Bool?
    public var issuesReported: String?
    public var imageUrls: [String]?
    public var createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId = "vehicle_id"
        case driverId = "driver_id"
        case inspectionType = "inspection_type"
        case brakesOk = "brakes_ok"
        case tiresOk = "tires_ok"
        case headlightsOk = "headlights_ok"
        case mirrorsOk = "mirrors_ok"
        case engineOk = "engine_ok"
        case issuesReported = "issues_reported"
        case imageUrls = "image_urls"
        case createdAt = "created_at"
    }
}
