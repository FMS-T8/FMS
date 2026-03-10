import Foundation

public struct DriverVehicleAssignment: Codable, Identifiable {
    public var id: String
    public var driverId: String?
    public var vehicleId: String?
    public var shiftStart: Date?
    public var shiftEnd: Date?
    public var status: String?
    public var createdBy: String?
    public var createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case driverId = "driver_id"
        case vehicleId = "vehicle_id"
        case shiftStart = "shift_start"
        case shiftEnd = "shift_end"
        case status
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}
