import Foundation
import Observation
import Supabase

@Observable
public class DashboardViewModel {
    public var alerts: [(title: String, subtitle: String, timeAgo: String, type: AlertType)] = []
    public var isLoading = false
    public var errorMessage: String? = nil
    
    private let client = SupabaseService.shared.client
    
    public init() {}
    
    @MainActor
    public func fetchData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 1. Fetch all vehicles to get their plate numbers mapping
            let fetchedVehicles: [Vehicle] = try await client
                .from("vehicles")
                .select()
                .execute()
                .value
            
            print("DEBUG: Fetched \(fetchedVehicles.count) vehicles")
            let vehicleMap = Dictionary(uniqueKeysWithValues: fetchedVehicles.map { ($0.id, $0) })
            
            // 2. Fetch all vehicle documents
            let fetchedDocuments: [VehicleDocument] = try await client
                .from("vehicle_documents")
                .select()
                .execute()
                .value
            print("DEBUG: Fetched \(fetchedDocuments.count) documents")

            // 3. Fetch all defects (issues)
            let fetchedDefects: [Defect] = try await client
                .from("defects")
                .select()
                .execute()
                .value
            print("DEBUG: Fetched \(fetchedDefects.count) defects")

            // 4. Fetch drivers to map names
            let fetchedDrivers: [Driver] = try await client
                .from("drivers")
                .select()
                .execute()
                .value
            print("DEBUG: Fetched \(fetchedDrivers.count) drivers")
            let driverMap = Dictionary(uniqueKeysWithValues: fetchedDrivers.map { ($0.id, $0) })
            
            // 5. Generate alerts
            self.alerts = generateAlerts(
                from: fetchedDocuments,
                defects: fetchedDefects,
                vehicleMap: vehicleMap,
                driverMap: driverMap
            )
            print("DEBUG: Generated \(self.alerts.count) total alerts")
            
        } catch {
            errorMessage = error.localizedDescription
            print("Error fetching dashboard data: \(error)")
        }
        
        isLoading = false
    }
    
    private func generateAlerts(
        from documents: [VehicleDocument],
        defects: [Defect],
        vehicleMap: [String: Vehicle],
        driverMap: [String: Driver]
    ) -> [(title: String, subtitle: String, timeAgo: String, type: AlertType)] {
        let now = Date()
        let calendar = Calendar.current
        var combinedAlerts: [(title: String, subtitle: String, date: Date, type: AlertType)] = []
        
        // --- Document Alerts ---
        for doc in documents {
            guard let expiryDate = doc.expiryDate else { continue }
            guard let vehicle = vehicleMap[doc.vehicleId] else { continue }
            
            let diff = calendar.dateComponents([.day], from: now, to: expiryDate)
            let daysUntilExpiry = diff.day ?? 0
            
            if daysUntilExpiry <= 30 {
                let type: AlertType
                let statusPrefix: String
                
                if daysUntilExpiry < 0 {
                    type = .critical
                    statusPrefix = "Expired"
                } else if daysUntilExpiry < 7 {
                    type = .critical
                    statusPrefix = "Expiring in \(daysUntilExpiry)d"
                } else {
                    type = .warning
                    statusPrefix = "Expiring in \(daysUntilExpiry)d"
                }
                
                let title = "\(doc.documentType) \(statusPrefix)"
                let subtitle = "Vehicle \(vehicle.plateNumber) \(doc.documentType) needs renewal."
                
                combinedAlerts.append((title, subtitle, expiryDate, type))
            }
        }

        // --- Defect (Issue) Alerts ---
        for defect in defects {
            // Only show open issues as active dashboard alerts
            guard defect.status == "open" else { continue }
            
            let vehicle = vehicleMap[defect.vehicleId]
            let plate = vehicle?.plateNumber ?? "Unknown Vehicle"
            let reportedAt = defect.reportedAt ?? Date()
            
            let type: AlertType
            switch defect.priority?.lowercased() {
            case "critical": type = .critical
            case "high": type = .warning
            case "medium", "low": type = .info
            default: type = .info
            }
            
            let driverName = defect.reportedBy.flatMap { driverMap[$0]?.name } ?? "Driver"
            let title = "\(defect.title)"
            let subtitle = "\(driverName) reported an issue with \(plate): \(defect.description ?? "No description")."
            
            combinedAlerts.append((title, subtitle, reportedAt, type))
        }
        
        // Sort by priority and then by date (newest first)
        return combinedAlerts
            .sorted { (a, b) in
                if a.type != b.type {
                    func rank(_ t: AlertType) -> Int {
                        switch t {
                        case .critical: return 0
                        case .warning: return 1
                        case .info: return 2
                        }
                    }
                    return rank(a.type) < rank(b.type)
                }
                return a.date > b.date
            }
            .map { (title: $0.title, subtitle: $0.subtitle, timeAgo: formatTimeLabel(from: $0.date), type: $0.type) }
    }
    
    private func formatTimeLabel(from date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        
        if date < now {
            let diff = calendar.dateComponents([.day], from: date, to: now)
            let days = diff.day ?? 0
            if days == 0 { return "Today" }
            return "\(days)d ago"
        } else {
            let diff = calendar.dateComponents([.day], from: now, to: date)
            let days = diff.day ?? 0
            if days == 0 { return "Today" }
            return "in \(days)d"
        }
    }
}
