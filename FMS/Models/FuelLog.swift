import Foundation

public struct FuelLog: Codable, Identifiable {
    public var id: String
    public var tripId: String?
    public var driverId: String?
    public var fuelStation: String?
    public var amountPaid: Double?
    public var fuelVolume: Double?
    public var receiptImageUrl: String?
    public var loggedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case driverId = "driver_id"
        case fuelStation = "fuel_station"
        case amountPaid = "amount_paid"
        case fuelVolume = "fuel_volume"
        case receiptImageUrl = "receipt_image_url"
        case loggedAt = "logged_at"
    }
}
