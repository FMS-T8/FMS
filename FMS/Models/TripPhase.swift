import Foundation

public enum TripPhase: String, Codable, CaseIterable {
    case pickup
    case inTransit
    case inBreak
    case delivery

    public var title: String {
        switch self {
        case .pickup:
            return "Pickup"
        case .inTransit:
            return "In Transit"
        case .inBreak:
            return "Break"
        case .delivery:
            return "Delivered"
        }
    }
}
