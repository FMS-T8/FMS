import Foundation

public struct MaintenancePartsUsed: Codable, Identifiable {
    public var id: String
    public var workOrderId: String?
    public var partId: String?
    public var quantity: Int?
    public var cost: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case workOrderId = "work_order_id"
        case partId = "part_id"
        case quantity
        case cost
    }
}
