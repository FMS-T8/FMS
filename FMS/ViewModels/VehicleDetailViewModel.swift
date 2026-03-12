import Foundation
import Observation
import Supabase

@Observable
public class VehicleDetailViewModel {
    public var trips: [Trip] = []
    public var workOrders: [MaintenanceWorkOrder] = []
    public var incidents: [Incident] = []
    public var isLoadingTrips = false
    public var isLoadingWorkOrders = false
    public var isLoadingEvents = false
    public var tripsErrorMessage: String? = nil
    public var workOrdersErrorMessage: String? = nil
    public var incidentsErrorMessage: String? = nil
    
    public init() {}
    
    @MainActor
    public func fetch(vehicleId: String) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                await self?.fetchTrips(vehicleId: vehicleId)
            }
            group.addTask { [weak self] in
                await self?.fetchWorkOrders(vehicleId: vehicleId)
            }
            group.addTask { [weak self] in
                await self?.fetchIncidents(vehicleId: vehicleId)
            }
        }
    }
    
    @MainActor
    private func fetchTrips(vehicleId: String) async {
        isLoadingTrips = true
        defer { isLoadingTrips = false }
        
        do {
            let fetched: [Trip] = try await SupabaseService.shared.client
                .from("trips")
                .select()
                .eq("vehicle_id", value: vehicleId)
                .order("start_time", ascending: false)
                .execute()
                .value
            trips = fetched
            tripsErrorMessage = nil
        } catch {
            tripsErrorMessage = error.localizedDescription
            print("Error fetching trips: \(error)")
        }
    }
    
    @MainActor
    private func fetchWorkOrders(vehicleId: String) async {
        isLoadingWorkOrders = true
        defer { isLoadingWorkOrders = false }
        
        do {
            let fetched: [MaintenanceWorkOrder] = try await SupabaseService.shared.client
                .from("maintenance_work_orders")
                .select()
                .eq("vehicle_id", value: vehicleId)
                .order("created_at", ascending: false)
                .execute()
                .value
            workOrders = fetched
            workOrdersErrorMessage = nil
        } catch {
            workOrdersErrorMessage = error.localizedDescription
            print("Error fetching work orders: \(error)")
        }
    }
    
    @MainActor
    private func fetchIncidents(vehicleId: String) async {
        isLoadingEvents = true
        defer { isLoadingEvents = false }
        
        do {
            let fetched: [Incident] = try await SupabaseService.shared.client
                .from("incidents")
                .select()
                .eq("vehicle_id", value: vehicleId)
                .order("created_at", ascending: false)
                .execute()
                .value
            incidents = fetched
            incidentsErrorMessage = nil
        } catch {
            incidentsErrorMessage = error.localizedDescription
            print("Error fetching incidents: \(error)")
        }
    }
}
