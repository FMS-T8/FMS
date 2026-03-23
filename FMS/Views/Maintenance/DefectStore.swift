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
    var reportedBy: String?          // driver_id or name who reported
    var tripId: String?              // trip_id from DB
    var imageUrls: [String]?         // image_urls from DB
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
        case "tires", "tyres":          return "circle.fill"
        case "brakes":                  return "pause.rectangle.fill"
        case "electrical":              return "bolt.fill"
        case "body_damage", "body":     return "car.side.rear.open.fill"
        case "engine":                  return "engine.combustion"
        default:                        return "exclamationmark.triangle.fill"
        }
    }

    enum Priority: String, CaseIterable {
        case critical = "critical"
        case high     = "high"
        case medium   = "medium"
        case low      = "low"

        /// Uppercase label for display in the UI
        var displayLabel: String { rawValue.uppercased() }

        var color: Color {
            switch self {
            case .critical: return FMSTheme.alertRed
            case .high:     return FMSTheme.alertOrange
            case .medium:   return Color(red: 0.2, green: 0.5, blue: 1.0)
            case .low:      return FMSTheme.alertGreen
            }
        }

        static func from(_ string: String) -> Priority {
            switch string.lowercased() {
            case "critical":        return .critical
            case "high", "urgent":  return .high
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
        self.reportedBy  = defect.reportedBy
        self.tripId      = defect.tripId
        self.imageUrls   = defect.imageUrls
        self.linkedWorkOrderId = defect.workOrderId
    }

    // MARK: Convert to DB model
    func toDefect() -> Defect {
        Defect(
            id:          id.uuidString,
            vehicleId:   vehicleId,
            reportedBy:  reportedBy,
            workOrderId: linkedWorkOrderId,
            title:       title,
            description: description.isEmpty ? nil : description,
            category:    category,
            priority:    priority.rawValue,
            status:      status,
            reportedAt:  reportedAt,
            resolvedAt:  nil,
            tripId:      tripId,
            imageUrls:   imageUrls
        )
    }

    // Manual memberwise init (for local creation before saving)
    init(id: UUID = UUID(), title: String, vehicleId: String, vehicleDisplay: String = "", category: String,
         priority: Priority, description: String, reportedAt: Date,
         status: String = "open", reportedBy: String? = nil, tripId: String? = nil, imageUrls: [String]? = nil, linkedWorkOrderId: String? = nil) {
        self.id                = id
        self.title             = title
        self.vehicleId         = vehicleId
        self.vehicleDisplay    = vehicleDisplay.isEmpty ? vehicleId : vehicleDisplay
        self.category          = category
        self.priority          = priority
        self.description       = description
        self.reportedAt        = reportedAt
        self.status            = status
        self.reportedBy        = reportedBy
        self.tripId            = tripId
        self.imageUrls         = imageUrls
        self.linkedWorkOrderId = linkedWorkOrderId
    }
}

// MARK: - Defect Store
@MainActor
@Observable
class DefectStore {
    var defects: [DefectItem] = []
    var isLoading: Bool = false

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

    // MARK: - Supabase CRUD

    func fetchDefects() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let fetchedDefectsResp = try SupabaseService.shared.client
                .from("defects")
                .select()
                .order("reported_at", ascending: false)
                .execute()
                
            async let fetchedVehiclesResp = try SupabaseService.shared.client
                .from("vehicles")
                .select()
                .execute()
                
            let (defectsResp, vehiclesResp) = try await (fetchedDefectsResp, fetchedVehiclesResp)
            
            let decoder = supabaseDecoder
            let fetchedDefects = try decoder.decode([Defect].self, from: defectsResp.data)
            let fetchedVehicles = try decoder.decode([Vehicle].self, from: vehiclesResp.data)

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

            self.defects = mappedItems
        } catch {
            print("Error fetching defects or vehicles: \(error)")
        }
    }

    func addDefect(_ item: DefectItem) async throws {
        let db = item.toDefect()
        let response = try await SupabaseService.shared.client
            .from("defects")
            .insert(db)
            .select()
            .execute()
        
        let inserted = try supabaseDecoder.decode([Defect].self, from: response.data)

        if let first = inserted.first {
            var newItem = DefectItem(from: first)
            newItem.vehicleDisplay = item.vehicleDisplay
            self.defects.insert(newItem, at: 0)
        }
    }

    func updateDefect(_ item: DefectItem) async throws {
        let db = item.toDefect()
        try await SupabaseService.shared.client
            .from("defects")
            .update(db)
            .eq("id", value: item.id.uuidString)
            .execute()

        if let idx = self.defects.firstIndex(where: { $0.id == item.id }) {
            self.defects[idx] = item
        }
    }

    func deleteDefect(id: UUID) async throws {
        try await SupabaseService.shared.client
            .from("defects")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()

        self.defects.removeAll { $0.id == id }
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

        if let idx = self.defects.firstIndex(where: { $0.id == defectId }) {
            self.defects[idx].linkedWorkOrderId = workOrderId
            self.defects[idx].status            = "in_progress"
        }
    }

    // Legacy helpers
    func add(_ defect: DefectItem) async throws {
        try await addDefect(defect)
    }
    func update(_ defect: DefectItem) async throws { try await updateDefect(defect) }
    func delete(id: UUID) async throws { try await deleteDefect(id: id) }
}