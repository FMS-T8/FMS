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
    
    public let statusOptions = ["All", "Active", "Inactive", "Maintenance"]
    
    public var filteredVehicles: [Vehicle] {
        var result = vehicles
        
        // Filter by status
        if selectedStatus != "All" {
            let normalizedSelected = VehicleStatus.normalize(selectedStatus)
            result = result.filter {
                VehicleStatus.normalize($0.status ?? "") == normalizedSelected
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
            let fetchedVehicles: [Vehicle] = try await SupabaseService.shared.client
                .from("vehicles")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
                
            self.vehicles = fetchedVehicles
            self.errorMessage = nil
            self.loadErrorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
            self.loadErrorMessage = error.localizedDescription
            print("Error fetching vehicles: \(error)")
            throw error
        }
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
        } catch {
            self.errorMessage = error.localizedDescription
            print("Error adding vehicle: \(error)")
            throw mapVehicleMutationError(error)
        }
    }

    @MainActor
    public func updateVehicle(_ vehicle: Vehicle) async throws {
        do {
            try await SupabaseService.shared.client
                .from("vehicles")
                .update(vehicle)
                .eq("id", value: vehicle.id)
                .execute()
            
            try await fetchVehicles()
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
            || message.contains("connection") {
            return .networkError
        }
        
        return .unknown
    }
}
