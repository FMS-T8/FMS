import Foundation

public struct Driver: Codable, Identifiable {
    public var id: String
    public var companyID: String
    public var name: String
    public var employeeID: String
    
    public init(id: String = UUID().uuidString, companyID: String, name: String, employeeID: String) {
        self.id = id
        self.companyID = companyID
        self.name = name
        self.employeeID = employeeID
    }
}
