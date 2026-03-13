import Foundation

public struct PartsInventory: Codable, Identifiable {
    public var id: UUID?
    public var name: String?
    public var stock: Int?
    public var threshold: Int?
    public var unitCost: Double?
    public var lastUpdated: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case stock
        case threshold
        case unitCost = "unit_cost"
        case lastUpdated = "last_updated"
    }
}
