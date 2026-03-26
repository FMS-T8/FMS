import Foundation
import Supabase
import Observation

@Observable
public class BudgetService {
    public static let shared = BudgetService()
    
    private init() {}
    
    public struct BudgetStatus {
        public let currentSpend: Double
        public let budgetLimit: Double
        public var consumptionPercentage: Double {
            guard budgetLimit > 0 else { return 0 }
            return (currentSpend / budgetLimit) * 100
        }
        public var isAlertThresholdReached: Bool {
            consumptionPercentage >= 80.0
        }
    }
    
    /// Fetches the monthly budget status for a specific vehicle.
    public func getBudgetStatus(for vehicle: Vehicle) async -> BudgetStatus {
        let budgetLimit = vehicle.effectiveMonthlyBudget
        
        let components = Calendar.current.dateComponents([.year, .month], from: Date())
        let startOfMonth = Calendar.current.date(from: components) ?? Date()
        
        // 1. Fetch Fuel Spend
        let fuelSpend = await fetchFuelSpend(for: vehicle.id, since: startOfMonth)
        
        // 2. Fetch Maintenance Spend (Granular parts + Work Order estimates)
        let maintenanceSpend = await fetchMaintenanceSpend(for: vehicle.id, since: startOfMonth)
        
        return BudgetStatus(
            currentSpend: fuelSpend + maintenanceSpend,
            budgetLimit: budgetLimit
        )
    }
    
    private func fetchFuelSpend(for vehicleId: String, since: Date) async -> Double {
        do {
            // First, get all trips for this vehicle this month
            let trips: [Trip] = try await SupabaseService.shared.client
                .from("trips")
                .select("id")
                .eq("vehicle_id", value: vehicleId)
                .gte("start_time", value: since)
                .execute()
                .value
            
            let tripIds = trips.map { $0.id }
            var totalFuelSpend: Double = 0
            
            // A. Logs directly linked to trips
            if !tripIds.isEmpty {
                let tripResponse = try await SupabaseService.shared.client
                    .from("fuel_logs")
                    .select("id, amount_paid")
                    .in("trip_id", values: tripIds)
                    .execute()
                
                let tripLogs: [FuelLog] = try JSONDecoder.supabase().decode([FuelLog].self, from: tripResponse.data)
                totalFuelSpend += tripLogs.reduce(0) { $0 + ($1.amountPaid ?? 0) }
            }
            
            // B. Standalone logs by drivers assigned to this vehicle this month
            // We fetch assignments for this vehicle this month
            let assignments: [DriverVehicleAssignment] = try await SupabaseService.shared.client
                .from("driver_vehicle_assignments")
                .select("id, driver_id, shift_start, shift_end")
                .eq("vehicle_id", value: vehicleId)
                .gte("shift_start", value: since)
                .execute()
                .value
            
            for assignment in assignments {
                guard let driverId = assignment.driverId, let start = assignment.shiftStart else { continue }
                let end = assignment.shiftEnd ?? Date()
                
                let driverLogs: [FuelLog] = try await SupabaseService.shared.client
                    .from("fuel_logs")
                    .select("id, amount_paid")
                    .eq("driver_id", value: driverId)
                    .is("trip_id", value: nil) // Avoid double counting A
                    .gte("logged_at", value: start)
                    .lte("logged_at", value: end)
                    .execute()
                    .value
                
                totalFuelSpend += driverLogs.reduce(0) { $0 + ($1.amountPaid ?? 0) }
            }
            
            return totalFuelSpend
        } catch is CancellationError {
            return 0
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == -999 {
            return 0
        } catch {
            print("[BudgetService] Error fetching fuel spend: \(error)")
            return 0
        }
    }
    
    private func fetchMaintenanceSpend(for vehicleId: String, since: Date) async -> Double {
        do {
            // Fetch all work orders for this month
            let workOrders: [MaintenanceWorkOrder] = try await SupabaseService.shared.client
                .from("maintenance_work_orders")
                .select("id, estimated_cost")
                .eq("vehicle_id", value: vehicleId)
                .gte("created_at", value: since)
                .execute()
                .value
            
            let woIds = workOrders.map { $0.id }
            if woIds.isEmpty { return 0 }
            
            // Fetch granular parts cost for these work orders
            let partsResponse = try await SupabaseService.shared.client
                .from("maintenance_parts_used")
                .select("id, work_order_id, cost")
                .in("work_order_id", values: woIds)
                .execute()
            
            let partsLogs: [MaintenancePartsUsed] = try JSONDecoder.supabase().decode([MaintenancePartsUsed].self, from: partsResponse.data)
            
            var totalMaintenanceSpend: Double = 0
            
            for wo in workOrders {
                let actualPartsCost = partsLogs.filter { $0.workOrderId == wo.id }.reduce(0) { $0 + ($1.cost ?? 0) }
                
                // If actual parts exist, prioritize them. If not, use the estimate.
                if actualPartsCost > 0 {
                    totalMaintenanceSpend += actualPartsCost
                } else {
                    totalMaintenanceSpend += wo.estimatedCost ?? 0
                }
            }
            
            return totalMaintenanceSpend
        } catch is CancellationError {
            return 0
        } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == -999 {
            return 0
        } catch {
            print("[BudgetService] Error fetching maintenance spend: \(error)")
            return 0
        }
    }
}
