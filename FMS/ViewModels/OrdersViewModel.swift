//
//  OrdersViewModel.swift
//  FMS
//
//  Created by user@50 on 16/03/26.
//


import Foundation
import Observation
import Supabase
import MapKit
import CoreLocation

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
    @MainActor
    public func fetchAvailableResources(for date: Date? = nil) async {
        do {
            let allDrivers: [LiveDriverResource] = try await SupabaseService.shared.client
                .from("users")
                .select("id, name")
                .eq("role", value: "driver")
                .eq("is_deleted", value: false)
                .eq("employment_status", value: "active")
                .execute()
                .value
            
            let allVehicles: [LiveVehicleResource] = try await SupabaseService.shared.client
                .from("vehicles")
                .select("id, plate_number, manufacturer, model")
                .eq("status", value: "active")
                .execute()
                .value
            
            if let targetDate = date {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(identifier: "UTC")!
                let startOfDay = calendar.startOfDay(for: targetDate)
                let endOfDay   = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let startStr = isoFormatter.string(from: startOfDay)
                let endStr   = isoFormatter.string(from: endOfDay)
                
                struct BusyTrip: Decodable {
                    let driver_id: String?
                    let vehicle_id: String?
                }
                
                let busyTrips: [BusyTrip] = try await SupabaseService.shared.client
                    .from("trips")
                    .select("driver_id, vehicle_id, orders!trips_order_id_fkey!inner(requested_pickup_at)")
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
    public func createOrder(payload: OrderCreatePayload, driverId: String? = nil, vehicleId: String? = nil) async -> Bool {
        isCreating = true
        errorMessage = nil
        do {
            let createdOrder: Order = try await SupabaseService.shared.client
                .from("orders")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value
            
            if let dId = driverId, let vId = vehicleId {
                try await assignTrip(orderId: createdOrder.id, driverId: dId, vehicleId: vId)
            } else {
                await fetchOrders()
            }
            
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
        let orders: [Order] = try await SupabaseService.shared.client
            .from("orders")
            .select()
            .eq("id", value: orderId)
            .execute()
            .value
        
        guard let order = orders.first else {
            throw NSError(domain: "OrderError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Order not found"])
        }
        
        // ── Calculate route distance & duration via MapKit ──────────────────────
        var routeDistanceKm: Double? = nil
        var estimatedDurationMin: Int? = nil
        
        if let originLat = order.originLat, let originLng = order.originLng,
           let destLat = order.destinationLat, let destLng = order.destinationLng {
            let result = await calculateRoute(
                from: CLLocationCoordinate2D(latitude: originLat, longitude: originLng),
                to: CLLocationCoordinate2D(latitude: destLat, longitude: destLng)
            )
            routeDistanceKm  = result.distanceKm
            estimatedDurationMin = result.durationMin
        }
        // ────────────────────────────────────────────────────────────────────────
        
        struct TripCreatePayload: Encodable {
            let order_id: String
            let driver_id: String
            let vehicle_id: String
            let status: String
            let shipment_description: String?
            let shipment_weight_kg: Double?
            let shipment_package_count: Int?
            let special_instructions: String?
            let start_name: String?
            let start_lat: Double?
            let start_lng: Double?
            let end_name: String?
            let end_lat: Double?
            let end_lng: Double?
            let distance_km: Double?
            let estimated_duration_minutes: Int?
        }
        
        let newTrip = TripCreatePayload(
            order_id: orderId, driver_id: driverId, vehicle_id: vehicleId,
            status: "scheduled",
            shipment_description: order.cargoType,
            shipment_weight_kg: order.totalWeightKg, shipment_package_count: order.totalPackages,
            special_instructions: order.specialInstructions,
            start_name: order.originName, start_lat: order.originLat, start_lng: order.originLng,
            end_name: order.destinationName, end_lat: order.destinationLat, end_lng: order.destinationLng,
            distance_km: routeDistanceKm,
            estimated_duration_minutes: estimatedDurationMin
        )
        
        struct InsertedTrip: Decodable { let id: String }
        
        let insertedTrips: [InsertedTrip] = try await SupabaseService.shared.client
            .from("trips")
            .insert(newTrip)
            .select("id")
            .execute()
            .value
        
        guard let generatedTripId = insertedTrips.first?.id else {
            throw NSError(domain: "TripError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to generate Trip ID"])
        }
        
        struct OrderUpdatePayload: Encodable {
            let status: String
            let trip_id: String
            let assigned_driver_id: String
            let assigned_vehicle_id: String
        }
        
        let updatePayload = OrderUpdatePayload(
            status: "confirmed",
            trip_id: generatedTripId,
            assigned_driver_id: driverId, assigned_vehicle_id: vehicleId
        )
        
        try await SupabaseService.shared.client
            .from("orders")
            .update(updatePayload)
            .eq("id", value: orderId)
            .execute()
        
        await fetchOrders()
    }
    
    // MARK: - Route Calculator (MapKit)
    private func calculateRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async -> (distanceKm: Double?, durationMin: Int?) {
        let request = MKDirections.Request()
        request.source      = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile
        
        do {
            let response = try await MKDirections(request: request).calculate()
            if let route = response.routes.first {
                let km  = route.distance / 1000.0
                let min = Int(route.expectedTravelTime / 60)
                return (km, min)
            }
        } catch {
            print("MapKit route calculation failed: \(error)")
        }
        return (nil, nil)
    }
}

