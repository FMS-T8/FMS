import SwiftUI
import Supabase
import PostgREST

// MARK: - PartItem (UI display model — wraps PartsInventory)
struct PartItem: Identifiable {
    var id:        UUID
    var name:      String
    var partNumber: String    // stored in `id` field of PartsInventory (or derived)
    var stock:     Int
    var minStock:  Int        // maps to PartsInventory.threshold
    var unitCost:  Double?
    var imageName: String     // SF Symbol — UI only, not in DB model
    var lastUpdated: Date?

    var isLowStock: Bool  { stock <= minStock }
    var statusColor: Color { isLowStock ? FMSTheme.alertOrange : FMSTheme.alertGreen }

    // MARK: Convert from DB model
    init(from part: PartsInventory, imageName: String = "cube.box.fill") {
        let assignedId = part.id ?? UUID()
        self.id          = assignedId
        self.name        = part.name ?? "Unknown Part"
        self.partNumber  = assignedId.uuidString.prefix(8).uppercased() // derive a display part number from UUID
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
    init(id: UUID, name: String, partNumber: String, stock: Int, minStock: Int,
         unitCost: Double? = nil, imageName: String, lastUpdated: Date? = nil) {
        self.id          = id
        self.name        = name
        self.partNumber  = partNumber
        self.stock       = stock
        self.minStock    = minStock
        self.unitCost    = unitCost
        self.imageName   = imageName
        self.lastUpdated = lastUpdated
    }
}


// MARK: - Inventory Store
@Observable
class InventoryStore {
    // imageName is UI-only; key = PartsInventory.id
    private var imageMap: [UUID: String] = [:]

    var parts: [PartItem] = []
    
    // Add a loading state for UI
    var isLoading: Bool = false

    init() {
        // Will be populated by fetchParts()
    }

    var lowStockParts: [PartItem] { parts.filter(\.isLowStock) }

    // MARK: - Supabase CRUD
    
    func fetchParts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let fetchedParts: [PartsInventory] = try await SupabaseService.shared.client
                .from("parts_inventory")
                .select()
                .execute()
                .value
            
            await MainActor.run {
                self.parts = fetchedParts.map { dbPart in
                    // Determine a default icon based on name
                    let defaultIconName = defaultIcon(for: dbPart.name ?? "")
                    // Create a PartItem (which guarantees a non-optional id)
                    let partItem = PartItem(from: dbPart, imageName: defaultIconName)
                    // Preserve existing assigned icon if present, else use the default
                    let icon = self.imageMap[partItem.id] ?? defaultIconName
                    // Save back to the map using the non-optional id
                    self.imageMap[partItem.id] = icon
                    // Return the item with the decided icon
                    return PartItem(from: dbPart, imageName: icon)
                }
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

    func addPart(_ inv: PartsInventory, imageName: String = "cube.box.fill") {
        Task {
            do {
                try await SupabaseService.shared.client
                    .from("parts_inventory")
                    .insert(inv)
                    .execute()
                
                await MainActor.run {
                    let partItem = PartItem(from: inv, imageName: imageName)
                    self.imageMap[partItem.id] = imageName
                    self.parts.append(partItem)
                }
            } catch {
                print("Error saving part: \(error)")
            }
        }
    }

    func updatePart(_ updated: PartItem) {
        let dbModel = updated.toPartsInventory()
        Task {
            do {
                try await SupabaseService.shared.client
                    .from("parts_inventory")
                    .update(dbModel)
                    .eq("id", value: updated.id)
                    .execute()
                
                await MainActor.run {
                    if let idx = self.parts.firstIndex(where: { $0.id == updated.id }) {
                        self.parts[idx] = updated
                    }
                }
            } catch {
                print("Error updating part: \(error)")
            }
        }
    }

    func deletePart(id: UUID) {
        Task {
            do {
                try await SupabaseService.shared.client
                    .from("parts_inventory")
                    .delete()
                    .eq("id", value: id)
                    .execute()
                
                await MainActor.run {
                    self.parts.removeAll { $0.id == id }
                }
            } catch {
                print("Error deleting part: \(error)")
            }
        }
    }

    func reorder(part: PartItem, quantity: Int) {
        let newStock = part.stock + quantity
        var updatedDBModel = part.toPartsInventory()
        updatedDBModel.stock = newStock
        
        Task {
            do {
                // We update only the stock to be safe, but we can pass the whole object
                try await SupabaseService.shared.client
                    .from("parts_inventory")
                    .update(["stock": newStock])
                    .eq("id", value: part.id)
                    .execute()
                
                await MainActor.run {
                    if let idx = self.parts.firstIndex(where: { $0.id == part.id }) {
                        self.parts[idx].stock = newStock
                    }
                }
            } catch {
                print("Error reordering part: \(error)")
            }
        }
    }
}

