import Foundation
import Observation
import Supabase

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
    
    // Custom decoder/encoder to match the Supabase JSON date handling
    private var supabaseDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)
            
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            if let date = dateFormatter.date(from: dateStr) { return date }
            
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            if let date = dateFormatter.date(from: dateStr) { return date }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(dateStr)")
        }
        return decoder
    }
    
    public init() {
        Task {
            await fetchAlerts()
        }
    }
    
    @MainActor
    public func fetchAlerts() async {
        do {
            let response = try await SupabaseService.shared.client
                .from("vehicle_events")
                .select()
                .order("timestamp", ascending: false)
                .limit(20)
                .execute()
            
            let fetchedEvents = try supabaseDecoder.decode([VehicleEvent].self, from: response.data)
            self.alerts = fetchedEvents.map { mapToAlertData($0) }
            
        } catch {
            print("Error fetching alerts from Supabase: \(error)")
            // Fallback to mock locally if table acts up or doesn't exist yet
            loadMockAlerts()
        }
    }
    
    private func loadMockAlerts() {
        self.alerts = [
            AlertData(
                title: "Tyre pressure warning",
                subtitle: "Truck #402 reported low pressure in rear-left tyre.",
                timeAgo: "12m ago",
                type: .warning,
                timestamp: Date().addingTimeInterval(-12 * 60)
            )
        ]
    }
    
    /// Simulates a vehicle breaching a geofence and adds a critical alert to Supabase
    public func triggerSimulatedBreach() {
        Task {
            let event = VehicleEvent(vehicleID: "V-\(Int.random(in: 100...999))", eventType: .zoneBreach)
            await insertEvent(event)
        }
    }
    
    /// Simulates a vehicle approaching maintenance
    public func triggerPredictiveMaintenance() {
        Task {
            let event = VehicleEvent(vehicleID: "V-\(Int.random(in: 100...999))", eventType: .maintenanceAlert)
            await insertEvent(event)
        }
    }
    
    /// Simulates an overdue maintenance
    public func triggerOverdueMaintenance() {
        Task {
            let event = VehicleEvent(vehicleID: "V-\(Int.random(in: 100...999))", eventType: .overdueMaintenance)
            await insertEvent(event)
        }
    }
    
    private func insertEvent(_ event: VehicleEvent) async {
        do {
            try await SupabaseService.shared.client
                .from("vehicle_events")
                .insert(event)
                .execute()
            
            await fetchAlerts() // Refresh the dashboard after sending
        } catch {
            print("Failed to insert event to Supabase: \(error)")
            // Fallback visually if table doesn't exist yet so it remains testable
            let fallbackAlert = mapToAlertData(event)
            await MainActor.run {
                self.alerts.insert(fallbackAlert, at: 0)
            }
        }
    }
    
    private func mapToAlertData(_ event: VehicleEvent) -> AlertData {
        let title: String
        let subtitle: String
        let type: AlertType
        
        switch event.eventType {
        case .zoneBreach:
            title = "Geofence deviation"
            subtitle = "Vehicle \(event.vehicleID) exited designated boundary."
            type = .critical
        case .maintenanceAlert:
            title = "Maintenance Check"
            subtitle = "Vehicle \(event.vehicleID) flagged for maintenance review."
            type = .warning
        case .overdueMaintenance:
            title = "Overdue Maintenance"
            subtitle = "Vehicle \(event.vehicleID) has exceeded its service mileage limit."
            type = .critical
        case .harshBraking:
            title = "Harsh Braking"
            subtitle = "Vehicle \(event.vehicleID) executed harsh braking."
            type = .warning
        case .rapidAcceleration:
            title = "Rapid Acceleration"
            subtitle = "Vehicle \(event.vehicleID) accelerated quickly."
            type = .info
        case .highGImpact:
            title = "High G-Impact"
            subtitle = "Vehicle \(event.vehicleID) collision detected."
            type = .critical
        }
        
        return AlertData(title: title, subtitle: subtitle, timeAgo: formattedTimeAgo(for: event.timestamp), type: type, timestamp: event.timestamp)
    }
    
    /// Formatter to convert Date differences into a "Xm ago" style string
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
