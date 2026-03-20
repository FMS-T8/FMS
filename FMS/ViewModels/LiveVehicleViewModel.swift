//
//  LiveVehicleViewModel.swift
//  FMS
//
//  Created by Anish on 11/03/26.
//

//
//  LiveVehicleViewModel.swift
//  FMS
//

import Foundation
import SwiftUI
import Observation
import Supabase

@Observable
final class LiveVehicleViewModel {
    var vehicles: [Vehicle] = []
    var searchText: String = ""
    var isLoading: Bool = false
    var errorMessage: String? = nil
    
    // Computed property to handle search and strictly filter for "live" statuses
    var filteredVehicles: [Vehicle] {
        let liveVehicles = vehicles.filter { $0.status?.lowercased() != "maintenance" }
        
        if searchText.isEmpty {
            return liveVehicles
        } else {
            let search = searchText.lowercased()
            return liveVehicles.filter { vehicle in
                let plate = vehicle.plateNumber.lowercased()
                let make = vehicle.manufacturer?.lowercased() ?? ""
                let model = vehicle.model?.lowercased() ?? ""
                return plate.contains(search) || make.contains(search) || model.contains(search)
            }
        }
    }
    
    @MainActor
    func fetchVehicles() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Live Fetch: Completely replaces the mock array
            let fetchedVehicles: [Vehicle] = try await SupabaseService.shared.client
                .from("vehicles")
                .select()
                .execute()
                .value
            
            self.vehicles = fetchedVehicles
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
            print("🚨 LiveVehicleViewModel Error: \(error)")
        }
    }
}
