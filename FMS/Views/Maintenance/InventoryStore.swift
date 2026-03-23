import SwiftUI
import Supabase
import PostgREST

// MARK: - PartItem (UI display model — wraps PartsInventory)
public struct PartItem: Identifiable {
    public var id:        UUID
    public var name:      String
    public var partNumber: String { id.uuidString.prefix(8).uppercased() }   // derived-only, not editable
    public var stock:     Int
    public var minStock:  Int        // maps to PartsInventory.threshold
    public var unitCost:  Double?
    public var imageName: String     // SF Symbol — UI only, not in DB model
    public var lastUpdated: Date?

    var isLowStock: Bool  { stock <= minStock }
    var statusColor: Color { isLowStock ? FMSTheme.alertOrange : FMSTheme.alertGreen }

    // MARK: Convert from DB model
    public init(from part: PartsInventory, imageName: String = "cube.box.fill") {
        let assignedId = part.id ?? UUID()
        self.id          = assignedId
        self.name        = part.name ?? "Unknown Part"
        self.stock       = part.stock ?? 0
        self.minStock    = part.threshold ?? 0
        self.unitCost    = part.unitCost
        self.imageName   = imageName
        self.lastUpdated = part.lastUpdated
    }

    // MARK: Convert to DB model
    func toPartsInventory() -> PartsInventory {
        PartsInventory(
            id:          id,
            name:        name,
            stock:       stock,
            threshold:   minStock,
            unitCost:    unitCost,
            lastUpdated: lastUpdated ?? Date()
        )
    }

    // Manual memberwise init (for in-app creation)
    public init(id: UUID, name: String, stock: Int, minStock: Int,
         unitCost: Double? = nil, imageName: String, lastUpdated: Date? = nil) {
        self.id          = id
        self.name        = name
        self.stock       = stock
        self.minStock    = minStock
        self.unitCost    = unitCost
        self.imageName   = imageName
        self.lastUpdated = lastUpdated
    }
}


// MARK: - Inventory Store
@MainActor
@Observable
public class InventoryStore {
    // imageName is UI-only; key = PartsInventory.id
    private var imageMap: [UUID: String] = [:]

    var parts: [PartItem] = []
    
    // Add a loading state for UI
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

    public init() {
        // Will be populated by fetchParts()
    }

    var lowStockParts: [PartItem] { parts.filter(\.isLowStock) }

    // MARK: - Supabase CRUD
    
    func fetchParts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await SupabaseService.shared.client
                .from("parts_inventory")
                .select()
                .execute()
            
            let fetchedParts = try supabaseDecoder.decode([PartsInventory].self, from: response.data)
            
            self.parts = fetchedParts.map { dbPart in
                let defaultIconName = defaultIcon(for: dbPart.name ?? "")
                let partItem = PartItem(from: dbPart, imageName: defaultIconName)
                let icon = self.imageMap[partItem.id] ?? defaultIconName
                self.imageMap[partItem.id] = icon
                
                var finalPart = partItem
                finalPart.imageName = icon
                return finalPart
            }
        } catch {
            print("Error fetching parts: \(error)")
        }
    }

    private func defaultIcon(for partName: String) -> String {
        let nameLower = partName.lowercased()
        if nameLower.contains("filter") { return "wind" }
        if nameLower.contains("brake") { return "pause.rectangle.fill" }
        if nameLower.contains("plug") { return "bolt.fill" }
        if nameLower.contains("tyre") || nameLower.contains("tire") { return "circle.fill" }
        if nameLower.contains("belt") { return "arrow.triangle.2.circlepath" }
        return "cube.box.fill"
    }

    func addPart(_ inv: PartsInventory, imageName: String = "cube.box.fill") async throws {
        let response = try await SupabaseService.shared.client
            .from("parts_inventory")
            .insert(inv)
            .select()
            .execute()
            
        let inserted = try supabaseDecoder.decode([PartsInventory].self, from: response.data)
            
        guard let dbPart = inserted.first else {
            throw NSError(domain: "InventoryError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve the inserted part from the database."])
        }
        
        let partItem = PartItem(from: dbPart, imageName: imageName)
        self.imageMap[partItem.id] = imageName
        self.parts.append(partItem)
    }

    func updatePart(_ updated: PartItem) async throws {
        let dbModel = updated.toPartsInventory()
        try await SupabaseService.shared.client
            .from("parts_inventory")
            .update(dbModel)
            .eq("id", value: updated.id)
            .execute()
        
        if let idx = self.parts.firstIndex(where: { $0.id == updated.id }) {
            self.parts[idx] = updated
        }
    }

    func deletePart(id: UUID) async throws {
        try await SupabaseService.shared.client
            .from("parts_inventory")
            .delete()
            .eq("id", value: id)
            .execute()
        
        self.parts.removeAll { $0.id == id }
    }

    func reorder(part: PartItem, quantity: Int) async throws {
        let newStock = part.stock + quantity
        guard newStock >= 0 else { throw NSError(domain: "InventoryError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Stock cannot be negative"]) }

        let response = try await SupabaseService.shared.client
            .from("parts_inventory")
            .update(["stock": newStock])
            .eq("id", value: part.id)
            .eq("stock", value: part.stock)
            .select()
            .execute()
            
        let updatedParts = try supabaseDecoder.decode([PartsInventory].self, from: response.data)
            
        guard let updatedPart = updatedParts.first else {
            throw NSError(domain: "InventoryError", code: 409, userInfo: [NSLocalizedDescriptionKey: "Stock was modified by another transaction. Please try again."])
        }
        
        if let idx = self.parts.firstIndex(where: { $0.id == part.id }) {
            self.parts[idx].stock = updatedPart.stock ?? newStock
        }
    }
}