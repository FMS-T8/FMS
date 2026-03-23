import Foundation

public struct MaintenanceWorkOrder: Codable, Identifiable {
    public var id: String
    public var vehicleId: String?
    public var createdBy: String?
    public var assignedTo: String?
    public var description: String?
    public var priority: String?
    public var status: String?
    public var estimatedCost: Double?
    public var createdAt: Date?
    public var completedAt: Date?
    public var serviceOdometer: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId = "vehicle_id"
        case createdBy = "created_by"
        case assignedTo = "assigned_to"
        case description
        case priority
        case status
        case estimatedCost = "estimated_cost"
        case createdAt = "created_at"
        case completedAt = "completed_at"
        case serviceOdometer = "service_odometer"
    }
}
