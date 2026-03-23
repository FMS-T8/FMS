import SwiftUI
import PostgREST
import Supabase

// MARK: - WOItem (UI display model — wraps MaintenanceWorkOrder)
public struct WOItem: Identifiable {
    public var id: String { woNumber }
    public var woNumber:    String
    public var vehicleIdRaw: String
    public var vehicle:     String
    public var assignedTo:  String?
    public var description: String
    public var priority:    Priority
    public var status:      Status
    public var estimatedCost: Double?
    public var createdAt:   Date
    public var completedAt: Date?
    public var serviceOdometer: Double?

    // Extra for UI
    public var partsUsed: [MaintenancePartsUsed] = []

    public var isService: Bool {
        description.hasPrefix("[SERVICE]")
    }
    
    public var createdAgo: String {
        let diff = Int(Date().timeIntervalSince(createdAt))
        if diff < 3600  { return "\(diff / 60)m ago" }
        if diff < 86400 { return "\(diff / 3600)h ago" }
        let days = diff / 86400
        if days == 1 { return "Yesterday" }
        return "\(days)d ago"
    }

    // MARK: Convert from real DB model
    public init(from wo: MaintenanceWorkOrder) {
        self.woNumber     = wo.id
        self.vehicleIdRaw = wo.vehicleId ?? "Unknown"
        self.vehicle      = wo.vehicleId ?? "Unknown Vehicle"
        self.assignedTo   = wo.assignedTo
        self.description  = wo.description ?? ""
        self.priority     = Priority.from(wo.priority)
        self.status       = Status.from(wo.status)
        self.estimatedCost = wo.estimatedCost
        self.createdAt    = wo.createdAt ?? Date()
        self.completedAt  = wo.completedAt
        self.serviceOdometer = wo.serviceOdometer
    }

    // MARK: Convert to DB model (for persistence)
    public func toMaintenanceWorkOrder() -> MaintenanceWorkOrder {
        MaintenanceWorkOrder(
            id:            woNumber,
            vehicleId:     vehicleIdRaw,
            createdBy:     nil,
            assignedTo:    assignedTo,
            description:   description,
            priority:      priority.rawValue,
            status:        status.dbValue,
            estimatedCost: estimatedCost,
            createdAt:     createdAt,
            completedAt:   completedAt,
            serviceOdometer: serviceOdometer
        )
    }

    // Manual memberwise init (for in-app creation without a DB round-trip)
    public init(woNumber: String, vehicleIdRaw: String, vehicle: String, assignedTo: String? = nil,
          description: String, priority: Priority, status: Status,
          estimatedCost: Double? = nil, createdAt: Date, completedAt: Date? = nil,
          serviceOdometer: Double? = nil) {
        self.woNumber     = woNumber
        self.vehicleIdRaw = vehicleIdRaw
        self.vehicle      = vehicle
        self.assignedTo   = assignedTo
        self.description  = description
        self.priority     = priority
        self.status       = status
        self.estimatedCost = estimatedCost
        self.createdAt    = createdAt
        self.completedAt  = completedAt
        self.serviceOdometer = serviceOdometer
    }

    // MARK: - Enums
    public enum Priority: String, CaseIterable {
        case high   = "high"
        case medium = "medium"
        case low    = "low"

        public var color: Color {
            switch self {
            case .high:   return FMSTheme.alertRed
            case .medium: return FMSTheme.alertOrange
            case .low:    return FMSTheme.alertGreen
            }
        }

        public static func from(_ raw: String?) -> Priority {
            switch raw?.lowercased() {
            case "high":   return .high
            case "low":    return .low
            default:       return .medium
            }
        }
    }

    public enum Status: String, CaseIterable {
        case pending    = "Pending"
        case inProgress = "In Progress"
        case completed  = "Completed"

        public var color: Color {
            switch self {
            case .pending:    return FMSTheme.textSecondary
            case .inProgress: return FMSTheme.alertOrange
            case .completed:  return FMSTheme.alertGreen
            }
        }

        /// Maps to DB string values
        public var dbValue: String {
            switch self {
            case .pending:    return "pending"
            case .inProgress: return "in_progress"
            case .completed:  return "completed"
            }
        }

        public static func from(_ raw: String?) -> Status {
            switch raw?.lowercased() {
            case "in_progress", "in progress": return .inProgress
            case "completed":                  return .completed
            default:                           return .pending
            }
        }
    }
}

// MARK: - Work Order Store
@MainActor
@Observable
public class WorkOrderStore {
    public var orders: [WOItem] = []
    public var isLoading: Bool = false

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
            
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let date = dateFormatter.date(from: dateStr) { return date }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(dateStr)")
        }
        return decoder
    }

    public func fetchWorkOrders() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let fetchedWOsResp = try SupabaseService.shared.client
                .from("maintenance_work_orders")
                .select()
                .order("created_at", ascending: false)
                .execute()
                
            async let fetchedPartsResp = try SupabaseService.shared.client
                .from("maintenance_parts_used")
                .select()
                .execute()
                
            async let fetchedVehiclesResp = try SupabaseService.shared.client
                .from("vehicles")
                .select()
                .execute()
                
            let (woResp, partsResp, vehiclesResp) = try await (fetchedWOsResp, fetchedPartsResp, fetchedVehiclesResp)
            
            let decoder = supabaseDecoder
            let fetchedWOs = try decoder.decode([MaintenanceWorkOrder].self, from: woResp.data)
            let fetchedParts = try decoder.decode([MaintenancePartsUsed].self, from: partsResp.data)
            let fetchedVehicles = try decoder.decode([Vehicle].self, from: vehiclesResp.data)
            
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
            
            self.orders = mappedItems
        } catch {
            print("❌ WORKORDER_STORE_ERROR: \(error)")
        }
    }

    // Resolve a human-friendly vehicle label from the already-fetched orders cache
    private func resolvedVehicleLabel(for vehicleId: String?) -> String? {
        guard let vehicleId else { return nil }
        return orders.first(where: { $0.vehicleIdRaw == vehicleId })?.vehicle
    }

    // Accept a real MaintenanceWorkOrder → convert + insert
    public func add(_ wo: MaintenanceWorkOrder) async throws -> MaintenanceWorkOrder {
        let response = try await SupabaseService.shared.client
            .from("maintenance_work_orders")
            .insert(wo)
            .select() // Return the inserted row
            .single()
            .execute()
            
        let inserted = try supabaseDecoder.decode(MaintenanceWorkOrder.self, from: response.data)
            
        var item = WOItem(from: inserted)
        if let label = resolvedVehicleLabel(for: inserted.vehicleId) {
            item.vehicle = label
        }
        orders.insert(item, at: 0)
        
        return inserted
    }

    // Convenience: add from a WOItem directly (used internally / defect linking)
    public func addItem(_ item: WOItem) async throws -> MaintenanceWorkOrder {
        let dbModel = item.toMaintenanceWorkOrder()
        let response = try await SupabaseService.shared.client
            .from("maintenance_work_orders")
            .insert(dbModel)
            .select() // Return the inserted row
            .single()
            .execute()
            
        let inserted = try supabaseDecoder.decode(MaintenanceWorkOrder.self, from: response.data)
            
        var fetchedItem = WOItem(from: inserted)
        fetchedItem.vehicle = resolvedVehicleLabel(for: inserted.vehicleId) ?? item.vehicle
        orders.insert(fetchedItem, at: 0)
        
        return inserted
    }

    public func updateStatus(_ id: String, status: WOItem.Status, serviceOdometer: Double? = nil) async throws {
        guard let idx = orders.firstIndex(where: { $0.id == id }) else { return }
        var updatedItem = orders[idx]
        updatedItem.status = status
        updatedItem.completedAt = (status == .completed) ? Date() : nil
        if let odo = serviceOdometer {
            updatedItem.serviceOdometer = odo
        } else if status == .completed {
            // Keep existing if not provided
        } else if status != .completed {
             updatedItem.serviceOdometer = nil
        }
        
        if status == .completed && updatedItem.isService {
            // Require a concrete odometer for completion of service orders
            guard let odo = serviceOdometer else {
                throw NSError(domain: "WorkOrderStore", code: 400, userInfo: [NSLocalizedDescriptionKey: "Service odometer is required to complete this job."])
            }
            updatedItem.serviceOdometer = odo
        }
        
        let dbModel = updatedItem.toMaintenanceWorkOrder()
        
        try await SupabaseService.shared.client
            .from("maintenance_work_orders")
            .update(dbModel)
            .eq("id", value: dbModel.id)
            .execute()
        
        if status == .completed && updatedItem.isService {
            // Reset vehicle odometer record
            // We use the odometer provided at completion, but we don't save it to the WO table
            try await updateVehicleServiceRecords(vehicleId: updatedItem.vehicleIdRaw, odometer: serviceOdometer)
        }
        
        if let freshIdx = self.orders.firstIndex(where: { $0.id == id }) {
            self.orders[freshIdx].status = status
            self.orders[freshIdx].completedAt = updatedItem.completedAt
            self.orders[freshIdx].serviceOdometer = updatedItem.serviceOdometer
        }
    }



    private struct VehicleServiceUpdate: Encodable {
        let last_service_date: String
        let last_service_odometer: Double?
        let odometer: Double?
        let status: String
    }
    
    private func updateVehicleServiceRecords(vehicleId: String, odometer: Double?) async throws {
        let updateData = VehicleServiceUpdate(
            last_service_date: ISO8601DateFormatter().string(from: Date()),
            last_service_odometer: odometer,
            odometer: odometer,
            status: "active"
        )
        
        try await SupabaseService.shared.client
            .from("vehicles")
            .update(updateData)
            .eq("id", value: vehicleId)
            .execute()
    }

    public func update(_ wo: WOItem) async throws {
        let dbModel = wo.toMaintenanceWorkOrder()
        try await SupabaseService.shared.client
            .from("maintenance_work_orders")
            .update(dbModel)
            .eq("id", value: dbModel.id)
            .execute()
        if let idx = self.orders.firstIndex(where: { $0.id == wo.id }) {
            self.orders[idx] = wo
        }
    }

    public func delete(id: String) async throws {
        guard let item = orders.first(where: { $0.id == id }) else { return }
        try await SupabaseService.shared.client
            .from("maintenance_work_orders")
            .delete()
            .eq("id", value: item.woNumber)
            .execute()
        self.orders.removeAll { $0.id == id }
    }

    public func addPartUsed(_ part: MaintenancePartsUsed, to woId: String) async throws {
        try await SupabaseService.shared.client
            .from("maintenance_parts_used")
            .insert(part)
            .execute()
            
        if let idx = self.orders.firstIndex(where: { $0.id == woId }) {
            self.orders[idx].partsUsed.append(part)
        }
    }

    public func removePartUsed(_ partId: String, from woId: String) async throws {
        try await SupabaseService.shared.client
            .from("maintenance_parts_used")
            .delete()
            .eq("id", value: partId)
            .execute()
            
        if let idx = self.orders.firstIndex(where: { $0.id == woId }) {
            self.orders[idx].partsUsed.removeAll { $0.id == partId }
        }
    }

    public var pendingCount:    Int { orders.filter { $0.status == .pending }.count }
    public var inProgressCount: Int { orders.filter { $0.status == .inProgress }.count }
    public var completedCount:  Int { orders.filter { $0.status == .completed }.count }
}
