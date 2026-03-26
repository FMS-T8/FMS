import Foundation
import SwiftUI
import Observation
import Supabase

@Observable
public class FleetViewModel {
    public var vehicles: [Vehicle] = []
    public var isLoading = false
    public var errorMessage: String? = nil
    public var loadErrorMessage: String? = nil
    public var selectedStatus: String = "All"
    public var searchText: String = ""
    
    // Context for derived status
    private var activeTrips: [Trip] = []
    private var openWorkOrders: [MaintenanceWorkOrder] = []
    
    public let statusOptions = ["All", "Active", "Inactive", "Maintenance"]
    
    public var filteredVehicles: [Vehicle] {
        var result = vehicles
        
        // Filter by status
        if selectedStatus != "All" {
            let normalizedSelected = VehicleStatus.normalize(selectedStatus)
            result = result.filter { vehicle in
                VehicleStatus.normalize(derivedStatus(for: vehicle)) == normalizedSelected
            }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            result = result.filter { vehicle in
                let plate = vehicle.plateNumber.lowercased()
                let make = (vehicle.manufacturer ?? "").lowercased()
                let model = (vehicle.model ?? "").lowercased()
                return plate.contains(searchLower) || make.contains(searchLower) || model.contains(searchLower)
            }
        }
        
        return result
    }
    
    public init() {
        // Data loading triggered by views via .task
    }
    
    @MainActor
    public func fetchVehicles() async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let vehiclesFetch: [Vehicle] = SupabaseService.shared.client
                .from("vehicles")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
                
            async let tripsFetch: [Trip] = SupabaseService.shared.client
                .from("trips")
                .select()
                .is("end_time", value: nil)
                .execute()
                .value
            
            async let workOrdersFetch: [MaintenanceWorkOrder] = SupabaseService.shared.client
                .from("maintenance_work_orders")
                .select()
                .not("status", operator: .in, value: "('completed', 'cancelled')")
                .execute()
                .value

            let (v, t, w) = try await (vehiclesFetch, tripsFetch, workOrdersFetch)
            
            self.vehicles = v
            self.activeTrips = t
            self.openWorkOrders = w
            self.errorMessage = nil
            self.loadErrorMessage = nil
        } catch is CancellationError {
            // Ignore cancellation
            print("FleetViewModel: Fetch cancelled")
        } catch {
            self.errorMessage = error.localizedDescription
            self.loadErrorMessage = error.localizedDescription
            print("CRITICAL FLEET DECODING ERROR: \(error)")
            throw error
        }
    }

    public func derivedStatus(for vehicle: Vehicle) -> String {
        if activeTrips.contains(where: { trip in
            guard trip.vehicleId == vehicle.id else { return false }
            let s = trip.status?.lowercased() ?? ""
            // Only truly ongoing trips count as "active" for the dashboard label
            return (s == "in_progress" || s == "ongoing" || s == "active" || s == "in_transit") && trip.endTime == nil
        }) {
            return "active"
        }
        if openWorkOrders.contains(where: { $0.vehicleId == vehicle.id }) {
            return "maintenance"
        }
        return "inactive"
    }
    
    @MainActor
    public func addVehicle(_ vehicle: Vehicle) async throws {
        do {
            #if DEBUG
            // DEBUG: Print the raw JSON payload before Supabase attempts to encode it
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(vehicle), let jsonString = String(data: data, encoding: .utf8) {
                print("DEBUG JSON PAYLOAD TO SEND: \(jsonString)")
            } else {
                print("DEBUG JSON PAYLOAD FAILED TO ENCODE LOCALLY!")
            }
            #endif
            
            try await SupabaseService.shared.client
                .from("vehicles")
                .insert([vehicle])
                .execute()
            
            // Re-fetch or optimistically add. We'll simply re-fetch to ensure sync
            try await fetchVehicles()
        } catch is CancellationError {
            // Ignore cancellation
            print("FleetViewModel: Update/Add cancelled")
        } catch {
            self.errorMessage = error.localizedDescription
            print("Error adding vehicle: \(error)")
            throw mapVehicleMutationError(error)
        }
    }

    @MainActor
    public func updateVehicle(_ vehicle: Vehicle) async throws {
        do {
            // 1. Standard update (updates all non-nil fields)
            try await SupabaseService.shared.client
                .from("vehicles")
                .update(vehicle)
                .eq("id", value: vehicle.id)
                .execute()
            
            // 2. Explicitly clear maintenance overrides if they are nil in the object
            // This is needed because standard JSON encoding omits nil values instead of sending nulls.
            if vehicle.serviceIntervalKm == nil || vehicle.monthlyBudget == nil {
                struct MaintenanceNullUpdate: Encodable {
                    let interval: Double?
                    let budget: Double?
                    
                    func encode(to encoder: Encoder) throws {
                        var container = encoder.container(keyedBy: CodingKeys.self)
                        if interval == nil { try container.encodeNil(forKey: .service_interval_km) }
                        if budget == nil { try container.encodeNil(forKey: .monthly_budget) }
                    }
                    
                    enum CodingKeys: String, CodingKey {
                        case service_interval_km, monthly_budget
                    }
                }
                
                _ = try? await SupabaseService.shared.client
                    .from("vehicles")
                    .update(MaintenanceNullUpdate(interval: vehicle.serviceIntervalKm, budget: vehicle.monthlyBudget))
                    .eq("id", value: vehicle.id)
                    .execute()
            }
            
            try await fetchVehicles()
        } catch is CancellationError {
            // Ignore cancellation
            print("FleetViewModel: Update cancelled")
        } catch {
            self.errorMessage = error.localizedDescription
            print("Error updating vehicle: \(error)")
            throw mapVehicleMutationError(error)
        }
    }

    @MainActor
    public func deleteVehicle(id: String) async throws {
        do {
            try await SupabaseService.shared.client
                .from("vehicles")
                .delete()
                .eq("id", value: id)
                .execute()
            
            try await fetchVehicles()
        } catch {
            self.errorMessage = error.localizedDescription
            print("Error deleting vehicle: \(error)")
            throw error
        }
    }
    
    private func mapVehicleMutationError(_ error: Error) -> AddVehicleError {
        let message = error.localizedDescription.lowercased()
        
        if message.contains("duplicate")
            || message.contains("unique")
            || message.contains("already exists") {
            if message.contains("plate") {
                return .duplicatePlate
            }
            if message.contains("chassis") || message.contains("vin") {
                return .duplicateChassis
            }
        }
        
        if message.contains("network")
            || message.contains("offline")
            || message.contains("timed out")
            || message.contains("timeout")
            || message.contains("connection")
            || message.contains("cancelled") {
            return .networkError
        }
        
        return .unknown
    }
}