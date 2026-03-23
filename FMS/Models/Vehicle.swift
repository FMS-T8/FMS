import Foundation

public struct Vehicle: Codable, Identifiable, Hashable, Equatable {
    public var id: String
    public var plateNumber: String
    public var chassisNumber: String?
    public var manufacturer: String?
    public var model: String?
    public var fuelType: String?
    public var fuelTankCapacity: Double?
    public var carryingCapacity: Double?
    public var purchaseDate: String?
    public var odometer: Double?
    public var status: String?
    public var createdBy: String?
    public var createdAt: Date?
    public var lastServiceDate: Date?
    public var lastServiceOdometer: Double?
    public var serviceIntervalKm: Double?
    public var notes: String?
    public var imageUrls: [String]?
    public var isDeleted: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case plateNumber          = "plate_number"
        case chassisNumber        = "chassis_number"
        case manufacturer
        case model
        case fuelType             = "fuel_type"
        case fuelTankCapacity     = "fuel_tank_capacity"
        case carryingCapacity     = "carrying_capacity"
        case purchaseDate         = "purchase_date"
        case odometer
        case status
        case createdBy            = "created_by"
        case createdAt            = "created_at"
        case lastServiceDate      = "last_service_date"
        case lastServiceOdometer  = "last_service_odometer"
        case serviceIntervalKm    = "service_interval_km"
        case notes
        case imageUrls            = "image_urls"
        case isDeleted            = "is_deleted"
    }
}