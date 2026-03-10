import Foundation

public struct Company: Codable, Identifiable {
    public var id: String
    public var name: String
    public var vehicleIDs: [String]
    public var driverIDs: [String]
    
    public init(id: String = UUID().uuidString, name: String, vehicleIDs: [String] = [], driverIDs: [String] = []) {
        self.id = id
        self.name = name
        self.vehicleIDs = vehicleIDs
        self.driverIDs = driverIDs
    }
}
