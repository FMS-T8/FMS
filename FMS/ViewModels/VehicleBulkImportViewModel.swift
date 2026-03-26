//
//  VehicleBulkImportViewModel.swift
//  FMS
//
//  Created by Anish on 26/03/26.
//

import Foundation
import Observation
import Supabase

public struct BulkVehiclePayload: Encodable, Identifiable {
    public let id = UUID().uuidString
    
    public let plate_number: String
    public let manufacturer: String?
    public let model: String?
    public let fuel_type: String?
    public let fuel_tank_capacity: Double?
    public let carrying_capacity: Double?
    public let status: String
    
    enum CodingKeys: String, CodingKey {
        case plate_number, manufacturer, model, fuel_type, fuel_tank_capacity, carrying_capacity, status
    }
}

@MainActor
@Observable
public final class VehicleBulkImportViewModel {
    public var parsedVehicles: [BulkVehiclePayload] = []
    public var invalidRowCount: Int = 0
    
    public var isParsing: Bool = false
    public var isUploading: Bool = false
    public var errorMessage: String? = nil
    
    public init() {}
    
    // MARK: - Step 1: Parse & Validate
    public func processCSV(at url: URL) {
        isParsing = true
        errorMessage = nil
        
        Task {
            do {
                // Must access security-scoped resources if picking from iOS Files app
                guard url.startAccessingSecurityScopedResource() else {
                    throw CSVParser.CSVError.fileReadFailed
                }
                defer { url.stopAccessingSecurityScopedResource() }
                
                let rawRows = try CSVParser.parse(url: url)
                var validVehicles: [BulkVehiclePayload] = []
                var invalidCount = 0
                
                for row in rawRows {
                    // plate_number is NOT NULL UNIQUE in your DB schema
                    guard let plate = row["plate_number"], !plate.isEmpty else {
                        invalidCount += 1
                        continue
                    }
                    
                    let capacityStr = row["fuel_tank_capacity"] ?? ""
                    let carryStr = row["carrying_capacity"] ?? ""
                    
                    let vehicle = BulkVehiclePayload(
                        plate_number: plate,
                        manufacturer: row["manufacturer"],
                        model: row["model"],
                        // fuel_type CHECK constraints: 'diesel', 'petrol', 'electric'
                        fuel_type: row["fuel_type"]?.lowercased(),
                        fuel_tank_capacity: Double(capacityStr),
                        carrying_capacity: Double(carryStr),
                        // status CHECK constraints: 'active', 'maintenance', 'inactive'
                        status: row["status"]?.lowercased() ?? "active"
                    )
                    validVehicles.append(vehicle)
                }
                
                await MainActor.run {
                    self.parsedVehicles = validVehicles
                    self.invalidRowCount = invalidCount
                    self.isParsing = false
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isParsing = false
                }
            }
        }
    }
    
    // MARK: - Step 2: Upload to Supabase
    public func uploadVehicles(onSuccess: @escaping () -> Void) {
        guard !parsedVehicles.isEmpty else { return }
        isUploading = true
        errorMessage = nil
        
        Task { [weak self] in
            guard let self else { return }
            do {
                // Supabase supports array inserts directly
                try await SupabaseService.shared.client
                    .from("vehicles")
                    .insert(self.parsedVehicles)
                    .execute()
                
                await MainActor.run {
                    self.isUploading = false
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    self.isUploading = false
                    self.errorMessage = "Upload failed: \(error.localizedDescription). Check for duplicate plate numbers."
                }
            }
        }
    }
}
