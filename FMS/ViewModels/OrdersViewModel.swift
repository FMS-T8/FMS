//
//  OrdersViewModel.swift
//  FMS
//
//  Created by user@50 on 16/03/26.
//


import Foundation
import Observation
import Supabase

public struct LiveDriverResource: Decodable, Identifiable {
    public let id: String
    public let name: String
}

public struct LiveVehicleResource: Decodable, Identifiable {
    public let id: String
    public let plateNumber: String
    public let manufacturer: String?
    public let model: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case plateNumber = "plate_number"
        case manufacturer
        case model
    }
}

@Observable
public final class OrdersViewModel {
    public var allOrders: [Order] = []
    
    // Live Resources for the Picker Sheets
    public var availableDrivers: [LiveDriverResource] = []
    public var availableVehicles: [LiveVehicleResource] = []
    
    public var isLoading: Bool = false
    public var isCreating: Bool = false
    public var errorMessage: String? = nil
    
    public var pendingOrders: [Order] {
        allOrders.filter { $0.isPending }.sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
    }
    public var ongoingOrders: [Order] {
        allOrders.filter { $0.isOngoing }.sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
    }
    public var completedOrders: [Order] {
        allOrders.filter { $0.isCompleted }.sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
    }
    
    public init() {}
    
    // MARK: - Fetch Available Resources
    // Accepts an optional Date so call sites can filter out already-busy
    // drivers and vehicles. When nil, returns all active drivers/vehicles.
    @MainActor
    public func fetchAvailableResources(for date: Date? = nil) async {
        do {
            // 1. Fetch all active drivers and vehicles unconditionally first
            let allDrivers: [LiveDriverResource] = try await SupabaseService.shared.client
                .from("users")
                .select("id, name")
                .eq("role", value: "driver")
                .execute()
                .value
            
            let allVehicles: [LiveVehicleResource] = try await SupabaseService.shared.client
                .from("vehicles")
                .select("id, plate_number, manufacturer, model")
                .eq("status", value: "active")
                .execute()
                .value
            
            // 2. If a date was provided, fetch trips scheduled on that calendar day
            //    and subtract those drivers/vehicles from the available pool
            if let targetDate = date {
                // Build ISO-8601 day boundaries in UTC
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(identifier: "UTC")!
                let startOfDay = calendar.startOfDay(for: targetDate)
                let endOfDay   = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let startStr = isoFormatter.string(from: startOfDay)
                let endStr   = isoFormatter.string(from: endOfDay)
                
                // Fetch trips whose requested_pickup_at falls within that day
                struct BusyTrip: Decodable {
                    let driver_id: String?
                    let vehicle_id: String?
                }
                
                // Join trips → orders to get the pickup date
                let busyTrips: [BusyTrip] = try await SupabaseService.shared.client
                    .from("trips")
                    .select("driver_id, vehicle_id, orders!inner(requested_pickup_at)")
                    .gte("orders.requested_pickup_at", value: startStr)
                    .lt("orders.requested_pickup_at", value: endStr)
                    .neq("status", value: "cancelled")
                    .execute()
                    .value
                
                let busyDriverIds  = Set(busyTrips.compactMap(\.driver_id))
                let busyVehicleIds = Set(busyTrips.compactMap(\.vehicle_id))
                
                self.availableDrivers  = allDrivers.filter  { !busyDriverIds.contains($0.id) }
                self.availableVehicles = allVehicles.filter { !busyVehicleIds.contains($0.id) }
            } else {
                // No date filter — return everything active
                self.availableDrivers  = allDrivers
                self.availableVehicles = allVehicles
            }
            
        } catch {
            print("Failed to fetch live resources: \(error)")
        }
    }
    
    // MARK: - Fetch Orders
    @MainActor
    public func fetchOrders() async {
        isLoading = true
        errorMessage = nil
        do {
            let response: [Order] = try await SupabaseService.shared.client
                .from("orders")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            self.allOrders = response
        } catch {
            self.errorMessage = "Failed to load orders: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    // MARK: - Create Order
    @MainActor
    public func createOrder(
        payload: OrderCreatePayload,
        driverId: String? = nil,
        vehicleId: String? = nil
    ) async -> Bool {
        isCreating = true
        errorMessage = nil
        do {
            // 1. Insert the order
            let createdOrder: Order = try await SupabaseService.shared.client
                .from("orders")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value
            
            // 2. If "Assign Now" was chosen, create the trip immediately
            if let dId = driverId, let vId = vehicleId {
                try await assignTrip(orderId: createdOrder.id, driverId: dId, vehicleId: vId)
            }
            
            await fetchOrders()
            isCreating = false
            return true
        } catch {
            self.errorMessage = "Failed to create order: \(error.localizedDescription)"
            isCreating = false
            return false
        }
    }
    
    // MARK: - Assign Trip
    @MainActor
    public func assignTrip(orderId: String, driverId: String, vehicleId: String) async throws {
        struct TripCreatePayload: Encodable {
            let order_id: String
            let driver_id: String
            let vehicle_id: String
            let status: String
        }
        
        let newTrip = TripCreatePayload(
            order_id: orderId,
            driver_id: driverId,
            vehicle_id: vehicleId,
            status: "scheduled"
        )
        try await SupabaseService.shared.client
            .from("trips")
            .insert(newTrip)
            .execute()
        
        // Mark the order as confirmed
        struct OrderUpdate: Encodable { let status: String }
        try await SupabaseService.shared.client
            .from("orders")
            .update(OrderUpdate(status: "confirmed"))
            .eq("id", value: orderId)
            .execute()
        
        await fetchOrders()
    }
}
