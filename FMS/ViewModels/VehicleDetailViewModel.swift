import Foundation
import Observation
import Supabase

@Observable
public class VehicleDetailViewModel {
    public var trips: [Trip] = []
    public var workOrders: [MaintenanceWorkOrder] = []
    public var events: [VehicleEvent] = []
    public var isLoadingTrips = false
    public var isLoadingWorkOrders = false
    public var isLoadingEvents = false
    
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
                await self?.fetchEvents(vehicleId: vehicleId)
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
        } catch {
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
        } catch {
            print("Error fetching work orders: \(error)")
        }
    }
    
    @MainActor
    private func fetchEvents(vehicleId: String) async {
        isLoadingEvents = true
        defer { isLoadingEvents = false }
        
        do {
            let fetched: [VehicleEvent] = try await SupabaseService.shared.client
                .from("vehicle_events")
                .select()
                .eq("vehicle_id", value: vehicleId)
                .order("timestamp", ascending: false)
                .execute()
                .value
            events = fetched
        } catch {
            print("Error fetching vehicle events: \(error)")
        }
    }
}
