import Foundation
import Observation
import PostgREST
import Supabase

@MainActor
@Observable
public class MaintenanceSettingsStore {
    public var globalIntervalKm: String = "10000"
    public var isLoading = false
    
    public static let shared = MaintenanceSettingsStore()
    
    public static let systemVehicleID = "00000000-0000-0000-0000-000000000000"
    
    private init() {
        // Initial load from UserDefaults for immediate UI, then fetch from DB
        loadFromLocal()
    }
    
    public func fetchRemoteConfig() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response: [Vehicle] = try await SupabaseService.shared.client
                .from("vehicles")
                .select()
                .eq("id", value: MaintenanceSettingsStore.systemVehicleID)
                .execute()
                .value
            
            if let systemVehicle = response.first {
                self.globalIntervalKm = String(format: "%.0f", systemVehicle.serviceIntervalKm ?? 10000)
                saveToLocal()
                print("MaintenanceSettingsStore: Remote config loaded")
            } else {
                print("MaintenanceSettingsStore: System config row not found, using local defaults")
            }
        } catch {
            print("MaintenanceSettingsStore: Failed to fetch remote config: \(error)")
        }
    }
    
    public func save() async throws {
        guard !globalIntervalKm.isEmpty, let km = Double(globalIntervalKm), km > 0 else {
            print("MaintenanceSettingsStore: Invalid input, ignoring save")
            return
        }
        
        saveToLocal()
        
        let systemRow = SystemRow(
            id: MaintenanceSettingsStore.systemVehicleID,
            plate_number: "SYSTEM_SETTINGS",
            manufacturer: "System",
            model: "Maintenance Config",
            fuel_type: "petrol",
            odometer: 0,
            service_interval_km: intervalKmDouble,
            status: "inactive"
        )
        
        try await SupabaseService.shared.client
            .from("vehicles")
            .upsert(systemRow)
            .execute()
        
        print("MaintenanceSettingsStore: Remote config upserted")
    }
    
    private func loadFromLocal() {
        if let km = UserDefaults.standard.string(forKey: "fms_global_interval_km") {
            globalIntervalKm = km
        }
    }
    
    private func saveToLocal() {
        UserDefaults.standard.set(globalIntervalKm, forKey: "fms_global_interval_km")
    }
    
    public var intervalKmDouble: Double {
        Double(globalIntervalKm) ?? 10000.0
    }
}

private struct SystemRow: Encodable {
    let id: String
    let plate_number: String
    let manufacturer: String
    let model: String
    let fuel_type: String
    let odometer: Double
    let service_interval_km: Double
    let status: String
}
