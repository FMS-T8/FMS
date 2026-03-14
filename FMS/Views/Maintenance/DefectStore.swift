import SwiftUI
import PostgREST
import Supabase

// Force cache invalidation rebuilding DefectItem
// MARK: - DefectItem (UI display model — wraps Defect)
struct DefectItem: Identifiable {
    var id: UUID
    var title: String
    var vehicleId: String        // maps to DB vehicleId
    var vehicleDisplay: String   // maps to UI presentation
    var category: String
    var priority: Priority
    var description: String
    var reportedAt: Date
    var status: String
    var linkedWorkOrderId: String?   // work_order_id from DB

    var reportedAgo: String {
        let diff = Int(Date().timeIntervalSince(reportedAt))
        if diff < 3600 { return "\(diff / 60)m ago" }
        if diff < 86400 { return "\(diff / 3600)h ago" }
        let days = diff / 86400
        if days == 1 { return "Yesterday" }
        return "\(days)d ago"
    }

    var imageName: String {
        switch category.lowercased() {
        case "tyres":      return "circle.fill"
        case "brakes":     return "pause.rectangle.fill"
        case "electrical": return "bolt.fill"
        case "body":       return "car.side.rear.open.fill"
        default:           return "exclamationmark.triangle.fill"
        }
    }

    enum Priority: String, CaseIterable {
        case critical = "critical"
        case urgent   = "urgent"
        case medium   = "medium"
        case low      = "low"

        /// Uppercase label for display in the UI
        var displayLabel: String { rawValue.uppercased() }

        var color: Color {
            switch self {
            case .critical: return FMSTheme.alertRed
            case .urgent:   return FMSTheme.alertOrange
            case .medium:   return Color(red: 0.2, green: 0.5, blue: 1.0)
            case .low:      return FMSTheme.alertGreen
            }
        }

        static func from(_ string: String) -> Priority {
            switch string.lowercased() {
            case "critical":        return .critical
            case "high", "urgent":  return .urgent
            case "low":             return .low
            default:                return .medium
            }
        }
    }

    // MARK: Convert from DB model
    init(from defect: Defect) {
        self.id             = UUID(uuidString: defect.id) ?? UUID()
        self.title          = defect.title
        self.vehicleId      = defect.vehicleId
        self.vehicleDisplay = defect.vehicleId // Temporary fallback
        self.category       = defect.category ?? "Other"
        self.priority    = Priority.from(defect.priority ?? "medium")
        self.description = defect.description ?? ""
        self.reportedAt  = defect.reportedAt ?? Date()
        self.status      = defect.status ?? "open"
        self.linkedWorkOrderId = defect.workOrderId
    }

    // MARK: Convert to DB model
    func toDefect() -> Defect {
        Defect(
            id:          id.uuidString,
            vehicleId:   vehicleId,
            reportedBy:  nil,
            workOrderId: linkedWorkOrderId,
            title:       title,
            description: description.isEmpty ? nil : description,
            category:    category,
            priority:    priority.rawValue,
            status:      status,
            reportedAt:  reportedAt,
            resolvedAt:  nil
        )
    }

    // Manual memberwise init (for local creation before saving)
    init(id: UUID = UUID(), title: String, vehicleId: String, vehicleDisplay: String = "", category: String,
         priority: Priority, description: String, reportedAt: Date,
         status: String = "open", linkedWorkOrderId: String? = nil) {
        self.id                = id
        self.title             = title
        self.vehicleId         = vehicleId
        self.vehicleDisplay    = vehicleDisplay.isEmpty ? vehicleId : vehicleDisplay
        self.category          = category
        self.priority          = priority
        self.description       = description
        self.reportedAt        = reportedAt
        self.status            = status
        self.linkedWorkOrderId = linkedWorkOrderId
    }
}

// MARK: - Defect Store
@Observable
class DefectStore {
    var defects: [DefectItem] = []
    var isLoading: Bool = false

    // MARK: - Supabase CRUD

    func fetchDefects() async {
        await MainActor.run { isLoading = true }
defer { Task { await MainActor.run { self.isLoading = false } } }

        do {
            async let fetchedDefectsTask: [Defect] = try SupabaseService.shared.client
                .from("defects")
                .select()
                .order("reported_at", ascending: false)
                .execute()
                .value
                
            async let fetchedVehiclesTask: [Vehicle] = try SupabaseService.shared.client
                .from("vehicles")
                .select()
                .execute()
                .value
                
            let (fetchedDefects, fetchedVehicles) = try await (fetchedDefectsTask, fetchedVehiclesTask)

            var mappedItems = fetchedDefects.map { DefectItem(from: $0) }
            
            for i in mappedItems.indices {
                // Map the vehicle UUID to a readable name matching WorkOrderStore
                let originalId = mappedItems[i].vehicleId
                if let matchedVehicle = fetchedVehicles.first(where: { $0.id == originalId }) {
                    let make = matchedVehicle.manufacturer ?? "Unknown"
                    let model = matchedVehicle.model ?? "Vehicle"
                    let plate = matchedVehicle.plateNumber
                    
                    mappedItems[i].vehicleDisplay = "\(make) \(model) · \(plate)".trimmingCharacters(in: .whitespaces)
                }
            }

            await MainActor.run {
                self.defects = mappedItems
            }
        } catch {
            print("Error fetching defects or vehicles: \(error)")
        }
    }

    func addDefect(_ item: DefectItem) async throws {
        let db = item.toDefect()
        let inserted: [Defect] = try await SupabaseService.shared.client
            .from("defects")
            .insert(db)
            .select()
            .execute()
            .value

        await MainActor.run {
            if let first = inserted.first {
                var newItem = DefectItem(from: first)
                newItem.vehicleDisplay = item.vehicleDisplay
                self.defects.insert(newItem, at: 0)
            }
        }
    }

    func updateDefect(_ item: DefectItem) async throws {
        let db = item.toDefect()
        try await SupabaseService.shared.client
            .from("defects")
            .update(db)
            .eq("id", value: item.id.uuidString)
            .execute()

        await MainActor.run {
            if let idx = self.defects.firstIndex(where: { $0.id == item.id }) {
                self.defects[idx] = item
            }
        }
    }

    func deleteDefect(id: UUID) async throws {
        try await SupabaseService.shared.client
            .from("defects")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()

        await MainActor.run {
            self.defects.removeAll { $0.id == id }
        }
    }

    /// Links a work order to a defect: updates work_order_id + status in DB and locally.
    func linkWorkOrder(defectId: UUID, workOrderId: String) async throws {
        struct WOLink: Encodable {
            var work_order_id: String
            var status: String
        }
        try await SupabaseService.shared.client
            .from("defects")
            .update(WOLink(work_order_id: workOrderId, status: "in_progress"))
            .eq("id", value: defectId.uuidString)
            .execute()

        await MainActor.run {
            if let idx = self.defects.firstIndex(where: { $0.id == defectId }) {
                self.defects[idx].linkedWorkOrderId = workOrderId
                self.defects[idx].status            = "in_progress"
            }
        }
    }

    // Legacy helpers
    func add(_ defect: DefectItem) async throws {
        try await addDefect(defect)
    }
    func update(_ defect: DefectItem) async throws { try await updateDefect(defect) }
    func delete(id: UUID) async throws { try await deleteDefect(id: id) }
}