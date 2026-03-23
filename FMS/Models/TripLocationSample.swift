import Foundation

public struct TripLocationSample: Codable, Identifiable {
    public let id: String
    public let tripId: String
    public let phase: TripPhase
    public let latitude: Double
    public let longitude: Double
    public let timestamp: Date

    public init(
        id: String = UUID().uuidString,
        tripId: String,
        phase: TripPhase,
        latitude: Double,
        longitude: Double,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.tripId = tripId
        self.phase = phase
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
    }
}
