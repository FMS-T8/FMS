import Foundation

public struct Trip: Codable, Identifiable {
    public var id: String
    public var vehicleId: String?
    public var driverId: String?
    public var assignmentId: String?
    public var shipmentDescription: String?
    public var shipmentWeightKg: Double?
    public var shipmentPackageCount: Int?
    public var fragile: Bool?
    public var specialInstructions: String?
    public var startLat: Double?
    public var startLng: Double?
    public var startName: String?
    public var endLat: Double?
    public var endLng: Double?
    public var endName: String?
    public var distanceKm: Double?
    public var estimatedDurationMin: Int?
    public var actualDurationMin: Int?
    public var fuelUsedLiters: Double?
    public var status: String?
    public var createdBy: String?
    public var createdAt: Date?
    public var startTime: Date?
    public var endTime: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId = "vehicle_id"
        case driverId = "driver_id"
        case assignmentId = "assignment_id"
        case shipmentDescription = "shipment_description"
        case shipmentWeightKg = "shipment_weight_kg"
        case shipmentPackageCount = "shipment_package_count"
        case fragile
        case specialInstructions = "special_instructions"
        case startLat = "start_lat"
        case startLng = "start_lng"
        case startName = "start_name"
        case endLat = "end_lat"
        case endLng = "end_lng"
        case endName = "end_name"
        case distanceKm = "distance_km"
        case estimatedDurationMin = "estimated_duration_min"
        case actualDurationMin = "actual_duration_min"
        case fuelUsedLiters = "fuel_used_liters"
        case status
        case createdBy = "created_by"
        case createdAt = "created_at"
        case startTime = "start_time"
        case endTime = "end_time"
    }

    public var statusLabel: String {
        switch status?.lowercased() {
        case "completed": return "Completed"
        case "active": return "In Progress"
        case "scheduled": return "Scheduled"
        case "cancelled": return "Cancelled"
        default: return status?.capitalized ?? "Unknown"
        }
    }
}
