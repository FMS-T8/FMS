import Foundation

public struct ReportEmailSubscription: Codable, Identifiable {
    public var id: String
    public var userId: String
    public var email: String
    public var isActive: Bool
    public var dayOfWeek: Int
    public var createdAt: Date?
    
    public init(id: String = UUID().uuidString, userId: String, email: String, isActive: Bool = true, dayOfWeek: Int = 1) {
        self.id = id
        self.userId = userId
        self.email = email
        self.isActive = isActive
        self.dayOfWeek = dayOfWeek
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case email
        case isActive = "is_active"
        case dayOfWeek = "day_of_week"
        case createdAt = "created_at"
    }
}
