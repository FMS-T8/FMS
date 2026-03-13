import SwiftUI
import PostgREST
import Supabase

// MARK: - WOItem (UI display model — wraps MaintenanceWorkOrder)
struct WOItem: Identifiable {
    var id              = UUID()
    var woNumber:    String
    var vehicle:     String
    var assignedTo:  String?
    var description: String
    var priority:    Priority
    var status:      Status
    var estimatedCost: Double?
    var createdAt:   Date
    var completedAt: Date?

    // Extra for UI
    var partsUsed: [MaintenancePartsUsed] = []

    var createdAgo: String {
        let diff = Int(Date().timeIntervalSince(createdAt))
        if diff < 3600  { return "\(diff / 60)m ago" }
        if diff < 86400 { return "\(diff / 3600)h ago" }
        return "Yesterday"
    }

    // MARK: Convert from real DB model
    init(from wo: MaintenanceWorkOrder) {
        self.woNumber     = wo.id
        self.vehicle      = wo.vehicleId ?? "Unknown Vehicle"
        self.assignedTo   = wo.assignedTo
        self.description  = wo.description ?? ""
        self.priority     = Priority.from(wo.priority)
        self.status       = Status.from(wo.status)
        self.estimatedCost = wo.estimatedCost
        self.createdAt    = wo.createdAt ?? Date()
        self.completedAt  = wo.completedAt
    }

    // MARK: Convert to DB model (for persistence)
    func toMaintenanceWorkOrder() -> MaintenanceWorkOrder {
        MaintenanceWorkOrder(
            id:            woNumber,
            vehicleId:     vehicle,
            createdBy:     nil,
            assignedTo:    assignedTo,
            description:   description,
            priority:      priority.rawValue,
            status:        status.dbValue,
            estimatedCost: estimatedCost,
            createdAt:     createdAt,
            completedAt:   completedAt
        )
    }

    // Manual memberwise init (for in-app creation without a DB round-trip)
    init(woNumber: String, vehicle: String, assignedTo: String? = nil,
         description: String, priority: Priority, status: Status,
         estimatedCost: Double? = nil, createdAt: Date, completedAt: Date? = nil) {
        self.woNumber     = woNumber
        self.vehicle      = vehicle
        self.assignedTo   = assignedTo
        self.description  = description
        self.priority     = priority
        self.status       = status
        self.estimatedCost = estimatedCost
        self.createdAt    = createdAt
        self.completedAt  = completedAt
    }

    // MARK: - Enums
    enum Priority: String, CaseIterable {
        case high   = "high"
        case medium = "medium"
        case low    = "low"

        var color: Color {
            switch self {
            case .high:   return FMSTheme.alertRed
            case .medium: return FMSTheme.alertOrange
            case .low:    return FMSTheme.alertGreen
            }
        }

        static func from(_ raw: String?) -> Priority {
            switch raw?.lowercased() {
            case "high":   return .high
            case "low":    return .low
            default:       return .medium
            }
        }
    }

    enum Status: String, CaseIterable {
        case pending    = "Pending"
        case inProgress = "In Progress"
        case completed  = "Completed"

        var color: Color {
            switch self {
            case .pending:    return FMSTheme.textSecondary
            case .inProgress: return FMSTheme.alertOrange
            case .completed:  return FMSTheme.alertGreen
            }
        }

        /// Maps to DB string values
        var dbValue: String {
            switch self {
            case .pending:    return "pending"
            case .inProgress: return "in_progress"
            case .completed:  return "completed"
            }
        }

        static func from(_ raw: String?) -> Status {
            switch raw?.lowercased() {
            case "in_progress", "in progress": return .inProgress
            case "completed":                  return .completed
            default:                           return .pending
            }
        }
    }
}

// MARK: - Work Order Store
@Observable
class WorkOrderStore {
    var orders: [WOItem] = []
    var isLoading: Bool = false

    func fetchWorkOrders() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let fetchedWOsTask: [MaintenanceWorkOrder] = try SupabaseService.shared.client
                .from("maintenance_work_orders")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
                
            async let fetchedPartsTask: [MaintenancePartsUsed] = try SupabaseService.shared.client
                .from("maintenance_parts_used")
                .select()
                .execute()
                .value
                
            async let fetchedVehiclesTask: [Vehicle] = try SupabaseService.shared.client
                .from("vehicles")
                .select()
                .execute()
                .value
                
            let (fetchedWOs, fetchedParts, fetchedVehicles) = try await (fetchedWOsTask, fetchedPartsTask, fetchedVehiclesTask)
            
            var mappedItems = fetchedWOs.map { WOItem(from: $0) }
            for i in mappedItems.indices {
                mappedItems[i].partsUsed = fetchedParts.filter { $0.workOrderId == mappedItems[i].woNumber }
                
                // Map the vehicle UUID to a readable name
                if let vId = fetchedWOs[i].vehicleId,
                   let matchedVehicle = fetchedVehicles.first(where: { $0.id == vId }) {
                    
                    let make = matchedVehicle.manufacturer ?? "Unknown"
                    let model = matchedVehicle.model ?? "Vehicle"
                    let plate = matchedVehicle.plateNumber
                    
                    mappedItems[i].vehicle = "\(make) \(model) · \(plate)".trimmingCharacters(in: .whitespaces)
                }
            }
            
            await MainActor.run {
                self.orders = mappedItems
            }
        } catch {
            print("Error fetching work orders or parts or vehicles: \(error)")
        }
    }

    // Accept a real MaintenanceWorkOrder → convert + insert
    func add(_ wo: MaintenanceWorkOrder) async throws -> MaintenanceWorkOrder {
        let item = WOItem(from: wo)
        let inserted: MaintenanceWorkOrder = try await SupabaseService.shared.client
            .from("maintenance_work_orders")
            .insert(wo)
            .select() // Return the inserted row
            .single()
            .execute()
            .value
            
        await MainActor.run {
            orders.insert(item, at: 0)
        }
        
        return inserted
    }

    // Convenience: add from a WOItem directly (used internally / defect linking)
    func addItem(_ item: WOItem) async throws -> MaintenanceWorkOrder {
        let dbModel = item.toMaintenanceWorkOrder()
        let inserted: MaintenanceWorkOrder = try await SupabaseService.shared.client
            .from("maintenance_work_orders")
            .insert(dbModel)
            .select() // Return the inserted row
            .single()
            .execute()
            .value
            
        await MainActor.run {
            orders.insert(item, at: 0)
        }
        
        return inserted
    }

    func updateStatus(_ id: UUID, status: WOItem.Status) {
        if let idx = orders.firstIndex(where: { $0.id == id }) {
            var updatedItem = orders[idx]
            updatedItem.status = status
            if status == .completed { updatedItem.completedAt = Date() }
            let dbModel = updatedItem.toMaintenanceWorkOrder()
            
            Task {
                do {
                    try await SupabaseService.shared.client
                        .from("maintenance_work_orders")
                        .update(dbModel)
                        .eq("id", value: dbModel.id)
                        .execute()
                    
                    await MainActor.run {
                        self.orders[idx] = updatedItem
                    }
                } catch {
                    print("Error updating status in DB: \(error)")
                }
            }
        }
    }

    func update(_ wo: WOItem) {
        let dbModel = wo.toMaintenanceWorkOrder()
        Task {
            do {
                try await SupabaseService.shared.client
                    .from("maintenance_work_orders")
                    .update(dbModel)
                    .eq("id", value: dbModel.id)
                    .execute()
                await MainActor.run {
                    if let idx = self.orders.firstIndex(where: { $0.id == wo.id }) {
                        self.orders[idx] = wo
                    }
                }
            } catch {
                print("Error updating work order in DB: \(error)")
            }
        }
    }

    func delete(id: UUID) {
        guard let item = orders.first(where: { $0.id == id }) else { return }
        Task {
            do {
                try await SupabaseService.shared.client
                    .from("maintenance_work_orders")
                    .delete()
                    .eq("id", value: item.woNumber)
                    .execute()
                await MainActor.run {
                    self.orders.removeAll { $0.id == id }
                }
            } catch {
                print("Error deleting work order from DB: \(error)")
            }
        }
    }

    func addPartUsed(_ part: MaintenancePartsUsed, to woId: UUID) {
        Task {
            do {
                try await SupabaseService.shared.client
                    .from("maintenance_parts_used")
                    .insert(part)
                    .execute()
                    
                await MainActor.run {
                    if let idx = self.orders.firstIndex(where: { $0.id == woId }) {
                        self.orders[idx].partsUsed.append(part)
                    }
                }
            } catch {
                print("Error adding part used to DB: \(error)")
            }
        }
    }

    func removePartUsed(_ partId: String, from woId: UUID) {
        Task {
            do {
                try await SupabaseService.shared.client
                    .from("maintenance_parts_used")
                    .delete()
                    .eq("id", value: partId)
                    .execute()
                    
                await MainActor.run {
                    if let idx = self.orders.firstIndex(where: { $0.id == woId }) {
                        self.orders[idx].partsUsed.removeAll { $0.id == partId }
                    }
                }
            } catch {
                print("Error removing part used from DB: \(error)")
            }
        }
    }

    var pendingCount:    Int { orders.filter { $0.status == .pending }.count }
    var inProgressCount: Int { orders.filter { $0.status == .inProgress }.count }
    var completedCount:  Int { orders.filter { $0.status == .completed }.count }
}
