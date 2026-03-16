import Foundation
import Supabase

/// Real implementation of DriversDataSource using Supabase.
public final class SupabaseDriversDataSource: DriversDataSource {
    
    private let client = SupabaseService.shared.client
    
    public init() {}
    
    // Custom decoder to handle Supabase date formats
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
    
    public func fetchDrivers() async throws -> [DriverDisplayItem] {
        let decoder = supabaseDecoder
        
        // Fetch users with driver role
        let driversResponse = try await client
            .from("users")
            .select()
            .eq("role", value: "driver")
            .execute()
        let drivers = try decoder.decode([User].self, from: driversResponse.data)
        
        // Fetch all active assignments
        let nowISO = ISO8601DateFormatter().string(from: Date())
        let assignmentsResponse = try await client
            .from("driver_vehicle_assignments")
            .select()
            .eq("status", value: "scheduled")
            .gte("shift_end", value: nowISO)
            .execute()
        let assignments = try decoder.decode([DriverVehicleAssignment].self, from: assignmentsResponse.data)
            
        // Fetch all vehicles
        let vehiclesResponse = try await client
            .from("vehicles")
            .select()
            .execute()
        let vehicles = try decoder.decode([Vehicle].self, from: vehiclesResponse.data)
            
        // Fetch active trips
        let tripsResponse = try await client
            .from("trips")
            .select()
            .eq("status", value: "active")
            .execute()
        let trips = try decoder.decode([Trip].self, from: tripsResponse.data)
            
        return drivers.map { driver in
            let assignment = assignments.first { $0.driverId == driver.id }
            let vehicle = vehicles.first { $0.id == assignment?.vehicleId }
            let activeTrip = trips.first { $0.driverId == driver.id }
            
            // Determine availability status
            var availability: DriverAvailabilityStatus = .offDuty
            if activeTrip != nil {
                availability = .onTrip
            } else if assignment != nil {
                availability = .available
            }
            
            return DriverDisplayItem(
                id: driver.id,
                name: driver.name,
                employeeID: driver.employeeId ?? "#DRV-XXXX",
                phone: driver.phone,
                vehicleId: vehicle?.id,
                vehicleManufacturer: vehicle?.manufacturer,
                vehicleModel: vehicle?.model,
                plateNumber: vehicle?.plateNumber,
                availabilityStatus: availability,
                shiftStart: assignment?.shiftStart,
                shiftEnd: assignment?.shiftEnd,
                activeTripId: activeTrip?.id
            )
        }
    }
    
    public func fetchShifts() async throws -> [ShiftDisplayItem] {
        let decoder = supabaseDecoder
        
        // Fetch all assignments
        let assignmentsResponse = try await client
            .from("driver_vehicle_assignments")
            .select()
            .execute()
        let assignments = try decoder.decode([DriverVehicleAssignment].self, from: assignmentsResponse.data)
            
        let driversResponse = try await client
            .from("users")
            .select()
            .eq("role", value: "driver")
            .execute()
        let drivers = try decoder.decode([User].self, from: driversResponse.data)
            
        let vehiclesResponse = try await client
            .from("vehicles")
            .select()
            .execute()
        let vehicles = try decoder.decode([Vehicle].self, from: vehiclesResponse.data)
            
        return assignments.compactMap { assignment in
            guard let driverId = assignment.driverId,
                  let driver = drivers.first(where: { $0.id == driverId }) else { return nil }
            
            let vehicle = vehicles.first(where: { $0.id == assignment.vehicleId })
            
            // Map DB status to display status
            // DB: scheduled, completed, cancelled
            // UI: on_duty, break, not_started
            let status: String
            switch assignment.status {
            case "scheduled":
                if let start = assignment.shiftStart, Date() >= start {
                    status = "on_duty"
                } else {
                    status = "not_started"
                }
            case "completed", "cancelled":
                return nil
            default:
                status = "not_started"
            }
            
            return ShiftDisplayItem(
                id: assignment.id,
                driverId: driver.id,
                driverName: driver.name,
                vehicleId: vehicle?.id,
                vehicleManufacturer: vehicle?.manufacturer,
                vehicleModel: vehicle?.model,
                plateNumber: vehicle?.plateNumber,
                shiftStart: assignment.shiftStart,
                shiftEnd: assignment.shiftEnd,
                status: status
            )
        }
    }
}
