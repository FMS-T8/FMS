//
//  VehicleBulkImportViewModel.swift
//  FMS
//
//  Created by Anish on 26/03/26.
//

import Foundation
import Observation
import Supabase

// MARK: - Internal UI Model
public struct BulkVehicleUIModel: Identifiable {
    public var id = UUID().uuidString
    
    public var plate_number: String
    public var chassis_number: String
    public var manufacturer: String
    public var model: String
    public var fuel_type: String
    public var fuel_tank_capacity: String
    public var carrying_capacity: String
    public var purchase_date: String
    public var odometer: String
}

// MARK: - Supabase API Payload
struct VehicleBulkInsertPayload: Encodable {
    let plate_number: String
    let chassis_number: String?
    let manufacturer: String?
    let model: String?
    let fuel_type: String?
    let fuel_tank_capacity: Double?
    let carrying_capacity: Double?
    let purchase_date: String?
    let odometer: Double?
}

@MainActor
@Observable
public final class VehicleBulkImportViewModel {
    public var parsedVehicles: [BulkVehicleUIModel] = []
    
    public var isParsing: Bool = false
    public var isUploading: Bool = false
    
    public init() {}
    
    // MARK: - Validation
    public var hasValidationErrors: Bool {
        parsedVehicles.contains { vehicle in
            vehicle.plate_number.trimmingCharacters(in: .whitespaces).isEmpty ||
            vehicle.chassis_number.trimmingCharacters(in: .whitespaces).isEmpty ||
            vehicle.purchase_date.trimmingCharacters(in: .whitespaces).isEmpty ||
            vehicle.odometer.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }
    
    // MARK: - Parse
    public func processCSV(at url: URL) throws {
        isParsing = true
        defer { isParsing = false }
        
        guard url.startAccessingSecurityScopedResource() else {
            throw CSVParser.CSVError.fileReadFailed
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let rawRows = try CSVParser.parse(url: url)
        var uiModels: [BulkVehicleUIModel] = []
        
        for row in rawRows {
            let vehicle = BulkVehicleUIModel(
                plate_number: row["plate_number"] ?? "",
                chassis_number: row["chassis_number"] ?? "",
                manufacturer: row["manufacturer"] ?? "",
                model: row["model"] ?? "",
                fuel_type: row["fuel_type"] ?? "",
                fuel_tank_capacity: row["fuel_tank_capacity"] ?? "",
                carrying_capacity: row["carrying_capacity"] ?? "",
                purchase_date: row["purchase_date"] ?? "",
                odometer: row["odometer"] ?? ""
            )
            
            if !vehicle.plate_number.isEmpty || !vehicle.chassis_number.isEmpty || !vehicle.manufacturer.isEmpty {
                uiModels.append(vehicle)
            }
        }
        
        self.parsedVehicles = uiModels
    }
    
    // MARK: - Upload (With Duplicate Handling)
    public func uploadVehicles() async throws -> (inserted: Int, skipped: Int) {
        isUploading = true
        defer { isUploading = false }
        
        // 1. Fetch existing plates to prevent UNIQUE constraint errors
        struct PlateQuery: Decodable { let plate_number: String }
        let existingRecords: [PlateQuery] = try await SupabaseService.shared.client
            .from("vehicles")
            .select("plate_number")
            .execute()
            .value
            
        let existingPlates = Set(existingRecords.map { $0.plate_number.lowercased().trimmingCharacters(in: .whitespaces) })
        
        // 2. Filter out duplicates and map to strict payload
        var apiPayloads: [VehicleBulkInsertPayload] = []
        var skippedCount = 0
        
        for uiModel in parsedVehicles {
            let plate = uiModel.plate_number.trimmingCharacters(in: .whitespaces)
            
            // Skip if the vehicle already exists
            if existingPlates.contains(plate.lowercased()) {
                skippedCount += 1
                continue
            }
            
            let payload = VehicleBulkInsertPayload(
                plate_number: plate,
                chassis_number: uiModel.chassis_number.trimmingCharacters(in: .whitespaces),
                manufacturer: uiModel.manufacturer.trimmingCharacters(in: .whitespaces).isEmpty ? nil : uiModel.manufacturer.trimmingCharacters(in: .whitespaces),
                model: uiModel.model.trimmingCharacters(in: .whitespaces).isEmpty ? nil : uiModel.model.trimmingCharacters(in: .whitespaces),
                fuel_type: uiModel.fuel_type.trimmingCharacters(in: .whitespaces).isEmpty ? nil : uiModel.fuel_type.lowercased().trimmingCharacters(in: .whitespaces),
                fuel_tank_capacity: Double(uiModel.fuel_tank_capacity),
                carrying_capacity: Double(uiModel.carrying_capacity),
                purchase_date: uiModel.purchase_date.trimmingCharacters(in: .whitespaces),
                odometer: Double(uiModel.odometer)
            )
            apiPayloads.append(payload)
        }
        
        // 3. Perform the Bulk Insert ONLY if there are new vehicles
        if !apiPayloads.isEmpty {
            try await SupabaseService.shared.client
                .from("vehicles")
                .insert(apiPayloads)
                .execute()
        }
        
        return (inserted: apiPayloads.count, skipped: skippedCount)
    }
}
