import Foundation

public struct User: Codable, Identifiable {
    public var id: String
    public var name: String
    public var email: String?
    public var phone: String?
    public var role: String
    public var status: String?
    public var licenseNumber: String?
    public var licenseExpiry: Date?
    public var createdBy: String?
    public var createdAt: Date?
    public var lastLogin: Date?
    public var employeeId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case phone
        case role
        case status
        case licenseNumber = "license_number"
        case licenseExpiry = "license_expiry"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case lastLogin = "last_login"
        case employeeId = "employee_id"
    }
}
