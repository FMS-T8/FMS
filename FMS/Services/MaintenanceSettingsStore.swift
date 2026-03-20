import Foundation
import Observation
import PostgREST
import Supabase

@Observable
public class MaintenanceSettingsStore {
    public var globalIntervalKm: String = "10000"
    public var globalIntervalMonths: String = "6"
    public var isLoading = false
    
    public static let shared = MaintenanceSettingsStore()
    
    private let systemVehicleID = "00000000-0000-0000-0000-000000000000"
    
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
                .eq("id", value: systemVehicleID)
                .execute()
                .value
            
            if let systemVehicle = response.first {
                self.globalIntervalKm = String(format: "%.0f", systemVehicle.serviceIntervalKm ?? 10000)
                self.globalIntervalMonths = String(systemVehicle.serviceIntervalMonths ?? 6)
                saveToLocal()
                print("MaintenanceSettingsStore: Remote config loaded")
            } else {
                print("MaintenanceSettingsStore: System config row not found, using local defaults")
            }
        } catch {
            print("MaintenanceSettingsStore: Failed to fetch remote config: \(error)")
        }
    }
    
    public func save() {
        saveToLocal()
        
        Task {
            do {
                let systemRow = SystemRow(
                    id: systemVehicleID,
                    plate_number: "SYSTEM_SETTINGS",
                    manufacturer: "System",
                    model: "Maintenance Config",
                    fuel_type: "petrol",
                    odometer: 0,
                    service_interval_km: intervalKmDouble,
                    service_interval_months: intervalMonthsInt,
                    status: "inactive"
                )
                
                try await SupabaseService.shared.client
                    .from("vehicles")
                    .upsert(systemRow)
                    .execute()
                
                print("MaintenanceSettingsStore: Remote config upserted")
            } catch {
                print("MaintenanceSettingsStore: Failed to save remote config: \(error)")
            }
        }
    }
    
    private func loadFromLocal() {
        if let km = UserDefaults.standard.string(forKey: "fms_global_interval_km") {
            globalIntervalKm = km
        }
        if let months = UserDefaults.standard.string(forKey: "fms_global_interval_months") {
            globalIntervalMonths = months
        }
    }
    
    private func saveToLocal() {
        UserDefaults.standard.set(globalIntervalKm, forKey: "fms_global_interval_km")
        UserDefaults.standard.set(globalIntervalMonths, forKey: "fms_global_interval_months")
    }
    
    public var intervalKmDouble: Double {
        Double(globalIntervalKm) ?? 10000.0
    }
    
    public var intervalMonthsInt: Int {
        Int(globalIntervalMonths) ?? 6
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
    let service_interval_months: Int
    let status: String
}
