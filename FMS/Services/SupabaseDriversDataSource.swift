import Foundation
import Supabase

public final class SupabaseDriversDataSource: DriversDataSource {
    
    public init() {}
    
    public func fetchDrivers() async throws -> [DriverDisplayItem] {
        struct UserRow: Decodable {
            let id: String
            let name: String
            let phone: String?
            let employee_id: String?
            let operational_status: String?
        }
        
        let usersResponse: [UserRow] = try await SupabaseService.shared.client
            .from("users")
            .select("id, name, phone, employee_id, operational_status")
            .eq("role", value: "driver")
            .eq("is_deleted", value: false)
            .eq("employment_status", value: "active")
            .execute()
            .value
            
        return usersResponse.map { user in
            let status: DriverAvailabilityStatus = {
                switch user.operational_status {
                case "on_trip": return .onTrip
                case "available": return .available
                default: return .offDuty
                }
            }()
            
            return DriverDisplayItem(
                id: user.id,
                name: user.name,
                employeeID: user.employee_id ?? "EMP-\(user.id.prefix(6).uppercased())",
                phone: user.phone ?? "N/A",
                vehicleId: nil,
                vehicleManufacturer: nil,
                vehicleModel: nil,
                plateNumber: nil,
                availabilityStatus: status,
                shiftStart: nil,
                shiftEnd: nil,
                activeTripId: nil
            )
        }
    }
}
