import Foundation

public enum BreakType: String, Codable, CaseIterable, Identifiable {
    case rest = "Rest"
    case meal = "Meal"
    case fuelStop = "Fuel Stop"
    case other = "Other"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .rest: return "bed.double.fill"
        case .meal: return "fork.knife"
        case .fuelStop: return "fuelpump.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}
