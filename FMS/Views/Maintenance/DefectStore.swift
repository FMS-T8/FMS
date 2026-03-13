import SwiftUI
import PostgREST
import Supabase

// MARK: - DefectItem (UI display model — wraps Defect)
struct DefectItem: Identifiable {
    var id: UUID
    var title: String
    var vehicle: String          // maps to vehicleId
    var category: String
    var priority: Priority
    var description: String
    var reportedAt: Date
    var status: String
    var linkedWorkOrderId: String?   // work_order_id from DB

    var reportedAgo: String {
        let diff = Int(Date().timeIntervalSince(reportedAt))
        if diff < 3600  { return "\(diff / 60)m ago" }
        if diff < 86400 { return "\(diff / 3600)h ago" }
        return "Yesterday"
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
        self.id          = UUID(uuidString: defect.id) ?? UUID()
        self.title       = defect.title
        self.vehicle     = defect.vehicleId
        self.category    = defect.category ?? "Other"
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
            vehicleId:   vehicle,
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
    init(id: UUID = UUID(), title: String, vehicle: String, category: String,
         priority: Priority, description: String, reportedAt: Date,
         status: String = "open", linkedWorkOrderId: String? = nil) {
        self.id                = id
        self.title             = title
        self.vehicle           = vehicle
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
        isLoading = true
        defer { isLoading = false }

        do {
            let records: [Defect] = try await SupabaseService.shared.client
                .from("defects")
                .select()
                .order("reported_at", ascending: false)
                .execute()
                .value

            await MainActor.run {
                self.defects = records.map { DefectItem(from: $0) }
            }
        } catch {
            print("Error fetching defects: \(error)")
        }
    }

    func addDefect(_ item: DefectItem) {
        let db = item.toDefect()
        Task {
            do {
                let inserted: [Defect] = try await SupabaseService.shared.client
                    .from("defects")
                    .insert(db)
                    .select()
                    .execute()
                    .value

                await MainActor.run {
                    if let first = inserted.first {
                        let newItem = DefectItem(from: first)
                        self.defects.insert(newItem, at: 0)
                    }
                }
            } catch {
                print("Error saving defect: \(error)")
            }
        }
    }

    func updateDefect(_ item: DefectItem) {
        let db = item.toDefect()
        Task {
            do {
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
            } catch {
                print("Error updating defect: \(error)")
            }
        }
    }

    func deleteDefect(id: UUID) {
        Task {
            do {
                try await SupabaseService.shared.client
                    .from("defects")
                    .delete()
                    .eq("id", value: id.uuidString)
                    .execute()

                await MainActor.run {
                    self.defects.removeAll { $0.id == id }
                }
            } catch {
                print("Error deleting defect: \(error)")
            }
        }
    }

    /// Links a work order to a defect: updates work_order_id + status in DB and locally.
    func linkWorkOrder(defectId: UUID, workOrderId: String) {
        Task {
            do {
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
                        self.defects[idx].status            = "wo_created"
                    }
                }
            } catch {
                print("Error linking WO to defect: \(error)")
            }
        }
    }

    // Legacy helpers
    func add(_ defect: DefectItem) { addDefect(defect) }
    func update(_ defect: DefectItem) { updateDefect(defect) }
    func delete(id: UUID) { deleteDefect(id: id) }
}
