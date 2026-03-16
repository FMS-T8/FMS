import Foundation
import Observation

/// Model to represent an alert in the UI
public struct AlertData: Identifiable {
    public let id = UUID()
    public let title: String
    public let subtitle: String
    public let timeAgo: String
    public let type: AlertType
    public let timestamp: Date
}

@Observable
public final class AlertsViewModel {
    public var alerts: [AlertData] = []
    
    public init() {
        // Load some initial mock alerts
        loadMockAlerts()
    }
    
    private func loadMockAlerts() {
        self.alerts = [
            AlertData(
                title: "Tyre pressure warning",
                subtitle: "Truck #402 reported low pressure in rear-left tyre.",
                timeAgo: "12m ago",
                type: .warning,
                timestamp: Date().addingTimeInterval(-12 * 60)
            ),
            AlertData(
                title: "Driver break scheduled",
                subtitle: "Driver David R. is reaching mandatory rest limit in 15 mins.",
                timeAgo: "45m ago",
                type: .info,
                timestamp: Date().addingTimeInterval(-45 * 60)
            )
        ]
    }
    
    /// Simulates a vehicle breaching a geofence and adds a critical alert to the queue
    public func triggerSimulatedBreach() {
        // Here we simulate an event where GeofenceService detected a breach
        let newAlert = AlertData(
            title: "Geofence deviation",
            subtitle: "Truck #\(Int.random(in: 100...999)) exited the designated route area in North District.",
            timeAgo: "Just now",
            type: .critical,
            timestamp: Date()
        )
        // Add to the top of the alerts list
        alerts.insert(newAlert, at: 0)
    }
    
    /// Simulates a vehicle approaching its maintenance interval and adds a warning alert
    public func triggerPredictiveMaintenance() {
        let newAlert = AlertData(
            title: "Maintenance Approaching",
            subtitle: "Van #\(Int.random(in: 1000...9999)) is nearing its scheduled 10,000 km service interval.",
            timeAgo: "Just now",
            type: .warning,
            timestamp: Date()
        )
        alerts.insert(newAlert, at: 0)
    }
    
    /// Simulates a vehicle dangerously past its scheduled maintenance threshold
    public func triggerOverdueMaintenance() {
        let newAlert = AlertData(
            title: "Overdue Maintenance",
            subtitle: "Truck #\(Int.random(in: 100...999)) has exceeded its service mileage limit.",
            timeAgo: "Just now",
            type: .critical,
            timestamp: Date()
        )
        alerts.insert(newAlert, at: 0)
    }
    
    /// Formatter to convert Date differences into a "Xm ago" style string (Implementation can be expanded as needed)
    public func formattedTimeAgo(for date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 60 {
            return "Just now"
        } else if diff < 3600 {
            return "\(Int(diff / 60))m ago"
        } else if diff < 86400 {
            return "\(Int(diff / 3600))h ago"
        } else {
            return "\(Int(diff / 86400))d ago"
        }
    }
}
