import Foundation

public enum VehicleStatus {
    public static func normalize(_ status: String) -> String {
        let value = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch value {
        case "active", "on trip", "moving", "in transit":
            return "active"
        case "maintenance", "in service", "service":
            return "maintenance"
        case "inactive", "idle", "stopped", "in yard":
            return "inactive"
        default:
            return value
        }
    }
}
