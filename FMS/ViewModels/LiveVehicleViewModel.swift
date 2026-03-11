//
//  LiveVehicleViewModel.swift
//  FMS
//
//  Created by Anish on 11/03/26.
//

import Foundation
import SwiftUI
import Observation

@Observable
final class LiveVehicleViewModel {
    var vehicles: [Vehicle] = []
    var searchText: String = ""
    var isLoading: Bool = false
    var errorMessage: String? = nil
    
    private let supabaseService = SupabaseService.shared
    
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
    
    func fetchVehicles() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await Task.sleep(nanoseconds: 500_000_000)
            
            // Mock data strictly matching your standard
            self.vehicles = [
                Vehicle(
                    id: UUID().uuidString,
                    plateNumber: "KA 09 MA 1234",
                    chassisNumber: "CH1234",
                    manufacturer: "Volvo",
                    model: "FH16",
                    fuelType: "Diesel",
                    fuelTankCapacity: 400,
                    carryingCapacity: nil,
                    purchaseDate: nil,
                    odometer: nil,
                    status: "active",
                    createdBy: nil,
                    createdAt: Date()
                ),
                
                Vehicle(
                    id: UUID().uuidString,
                    plateNumber: "KA 09 MA 5678",
                    chassisNumber: "CH5678",
                    manufacturer: "Tata",
                    model: "Prima",
                    fuelType: "Diesel",
                    fuelTankCapacity: 350,
                    carryingCapacity: nil,
                    purchaseDate: nil,
                    odometer: nil,
                    status: "active",
                    createdBy: nil,
                    createdAt: Date()
                ),
                
                Vehicle(
                    id: UUID().uuidString,
                    plateNumber: "KA 09 MA 9012",
                    chassisNumber: "CH9012",
                    manufacturer: "Ashok Leyland",
                    model: "Boss",
                    fuelType: "Diesel",
                    fuelTankCapacity: 300,
                    carryingCapacity: nil,
                    purchaseDate: nil,
                    odometer: nil,
                    status: "inactive",
                    createdBy: nil,
                    createdAt: Date()
                ),
                
                Vehicle(
                    id: UUID().uuidString,
                    plateNumber: "KA 09 MA 3344",
                    chassisNumber: "CH3344",
                    manufacturer: "Eicher",
                    model: "Pro",
                    fuelType: "Diesel",
                    fuelTankCapacity: 250,
                    carryingCapacity: nil,
                    purchaseDate: nil,
                    odometer: nil,
                    status: "maintenance",
                    createdBy: nil,
                    createdAt: Date()
                )
            ]
        } catch {
            self.errorMessage = error.localizedDescription
            print("Error fetching vehicles: \(error)")
        }
    }
}
