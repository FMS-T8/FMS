import Foundation

public struct Vehicle: Codable, Identifiable, Equatable, Hashable {
    public var id: String
    public var plateNumber: String
    public var chassisNumber: String
    public var manufacturer: String?
    public var model: String?
    public var fuelType: String
    public var fuelTankCapacity: Double
    public var carryingCapacity: Double?
    public var purchaseDateString: String?
    public var odometer: Double?
    public var status: String?
    public var createdBy: String?
    public var createdAt: Date? // Changed to optional in case Supabase sends it differently, though it usually succeeds.
    
    public var purchaseDate: Date? {
        guard let str = purchaseDateString else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: str)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case plateNumber = "plate_number"
        case chassisNumber = "chassis_number"
        case manufacturer
        case model
        case fuelType = "fuel_type"
        case fuelTankCapacity = "fuel_tank_capacity"
        case carryingCapacity = "carrying_capacity"
        case purchaseDateString = "purchase_date"
        case odometer
        case status
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}
