import Foundation

public struct TripStop: Codable, Identifiable {
    public var id: String
    public var tripId: String?
    public var name: String?
    public var lat: Double?
    public var lng: Double?
    public var stopType: String?
    public var goodsDescription: String?
    public var packages: Int?
    public var weightKg: Double?
    public var receiverName: String?
    public var signatureUrl: String?
    public var photoUrl: String?
    public var deliveredAt: Date?
    public var sequenceNumber: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case name
        case lat
        case lng
        case stopType = "stop_type"
        case goodsDescription = "goods_description"
        case packages
        case weightKg = "weight_kg"
        case receiverName = "receiver_name"
        case signatureUrl = "signature_url"
        case photoUrl = "photo_url"
        case deliveredAt = "delivered_at"
        case sequenceNumber = "sequence_number"
    }
}
