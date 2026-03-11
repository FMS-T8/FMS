import Foundation

public struct VehicleDocument: Codable, Identifiable {
    public var id: String
    public var vehicleId: String
    public var documentType: String
    public var fileUrl: String
    public var expiryDate: Date?
    public var uploadedBy: String?
    public var uploadedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId = "vehicle_id"
        case documentType = "document_type"
        case fileUrl = "file_url"
        case expiryDate = "expiry_date"
        case uploadedBy = "uploaded_by"
        case uploadedAt = "uploaded_at"
    }
}
