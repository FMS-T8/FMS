import Foundation

public struct TelemetryData: Codable, Identifiable {
    public var id: String
    public var tripID: String
    public var latitude: Double
    public var longitude: Double
    public var timestamp: Date
    public var speed: Double
    
    public init(id: String = UUID().uuidString, tripID: String, latitude: Double, longitude: Double, timestamp: Date = Date(), speed: Double) {
        self.id = id
        self.tripID = tripID
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.speed = speed
    }
}
