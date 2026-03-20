import Foundation

public struct User: Codable, Identifiable, Hashable {
    public var id: String
    public var name: String
    public var email: String?
    public var phone: String?
    public var role: String
    public var licenseNumber: String?
    public var licenseExpiry: Date?
    public var createdBy: String?
    public var createdAt: Date?
    public var lastLogin: Date?
    public var profilePictureUrl: String?
    public var employeeId: String?
    public var mapPreference: String?
    public var units: String?
    public var twoFactorEnabled: Bool?
    public var isDeleted: Bool?
    
    public var employmentStatus: String?
    public var operationalStatus: String?

    enum CodingKeys: String, CodingKey {
        case id, name, email, phone, role
        case licenseNumber = "license_number"
        case licenseExpiry = "license_expiry"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case lastLogin = "last_login"
        case profilePictureUrl = "profile_picture_url"
        case employeeId = "employee_id"
        case mapPreference = "map_preference"
        case units
        case twoFactorEnabled = "two_factor_enabled"
        case isDeleted = "is_deleted"
        case employmentStatus = "employment_status"
        case operationalStatus = "operational_status"
    }
}
