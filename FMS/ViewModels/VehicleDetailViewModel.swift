import Foundation
import Observation
import Supabase

@Observable
public class VehicleDetailViewModel {
    public var trips: [Trip] = []
    public var workOrders: [MaintenanceWorkOrder] = []
    public var incidents: [Incident] = []
    public var documents: [VehicleDocument] = []
    public var isLoadingTrips = false
    public var isLoadingWorkOrders = false
    public var isLoadingEvents = false
    public var isLoadingDocuments = false
    public var tripsErrorMessage: String? = nil
    public var workOrdersErrorMessage: String? = nil
    public var incidentsErrorMessage: String? = nil
    public var documentsErrorMessage: String? = nil
    public var derivedStatus: String {
        // Priority 1: Ongoing Trip (Actually on the road)
        if ongoingTrip != nil {
            return "active"
        }
        
        // Priority 2: Open Maintenance
        if workOrders.contains(where: { order in
            let s = order.status?.lowercased() ?? ""
            return s != "completed" && s != "cancelled"
        }) {
            return "maintenance"
        }
        
        // Default: In Yard (even if a trip is scheduled but not started)
        return "inactive"
    }

    public var ongoingTrip: Trip? {
        trips.first { trip in
            let s = trip.status?.lowercased() ?? ""
            // Based on Trip.statusLabel "In Progress"
            return (s == "in_progress" || s == "ongoing" || s == "active" || s == "in_transit") && trip.endTime == nil
        }
    }

    public var scheduledTrips: [Trip] {
        trips.filter { trip in
            let s = trip.status?.lowercased() ?? ""
            // Based on Trip.statusLabel "Scheduled"
            return (s == "scheduled" || s == "assigned" || s == "pending") && trip.endTime == nil
        }
    }

    public var pastTrips: [Trip] {
        trips.filter { trip in
            let s = trip.status?.lowercased() ?? ""
            // Based on Trip.statusLabel "Completed" or has end time
            return s == "completed" || trip.endTime != nil || s == "cancelled"
        }
    }

    public init() {}
    
    @MainActor
    public func fetch(vehicleId: String) async {
        trips = []
        workOrders = []
        incidents = []
        documents = []
        tripsErrorMessage = nil
        workOrdersErrorMessage = nil
        incidentsErrorMessage = nil
        documentsErrorMessage = nil
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
            group.addTask { [weak self] in
                await self?.fetchDocuments(vehicleId: vehicleId)
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

    @MainActor
    private func fetchDocuments(vehicleId: String) async {
        isLoadingDocuments = true
        defer { isLoadingDocuments = false }

        do {
            let fetched: [VehicleDocument] = try await SupabaseService.shared.client
                .from("vehicle_documents")
                .select()
                .eq("vehicle_id", value: vehicleId)
                .order("document_type", ascending: true)
                .execute()
                .value
            documents = fetched
            documentsErrorMessage = nil
        } catch {
            documentsErrorMessage = error.localizedDescription
            print("Error fetching documents: \(error)")
        }
    }
}
