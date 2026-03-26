//
//  TrackingShipmentViewModel.swift
//  FMS
//
//  Created by Anish on 12/03/26.
//

import Foundation
import Observation
import CoreLocation
import Supabase

@Observable
public class TrackingShipmentViewModel {
    // Your actual database models
    public var trip: Trip?
    public var driver: Driver?
    public var vehicle: Vehicle?
    public var latestGPSLog: TripGPSLog?
    
    public var isLoading = false
    
    // Extracted properties for the Map
    public var currentCoordinate: CLLocationCoordinate2D? {
        guard let lat = latestGPSLog?.lat, let lng = latestGPSLog?.lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
    
    public var destinationCoordinate: CLLocationCoordinate2D? {
        guard let lat = trip?.endLat, let lng = trip?.endLng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
    
    // Formatting helpers for the UI
    public var formattedTripId: String {
        guard let id = trip?.id else { return "N/A" }
        return "TRP-\(id.prefix(6).uppercased())"
    }
    
    public var formattedEstimatedDate: String {
        guard let durationMin = trip?.estimatedDurationMinutes,
              let startTime = trip?.startTime else { return "Calculating..." }
        
        let estimatedEnd = startTime.addingTimeInterval(TimeInterval(durationMin * 60))
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter.string(from: estimatedEnd)
    }
    
    // Initializer for live data
    public init(trip: Trip? = nil, vehicle: Vehicle? = nil, driver: Driver? = nil, latestGPSLog: TripGPSLog? = nil) {
        self.trip = trip
        self.vehicle = vehicle
        self.driver = driver
        self.latestGPSLog = latestGPSLog
        
        // If no GPS log provided, use trip's start coordinates as a fallback for the map
        if latestGPSLog == nil {
            if let lat = trip?.startLat, let lng = trip?.startLng {
                self.latestGPSLog = TripGPSLog(id: "fallback", tripId: trip?.id ?? "", lat: lat, lng: lng, speed: 0, recordedAt: Date())
            }
        }
    }
    
    @MainActor
    public func fetchDetails() async {
        guard let trip = trip, let driverId = trip.driverId else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Fetch Driver Details from users table
            let userResponse: [User] = try await SupabaseService.shared.client
                .from("users")
                .select("id, name, phone, role, employee_id")
                .eq("id", value: driverId)
                .execute()
                .value
            
            if let user = userResponse.first {
                self.driver = Driver(
                    id: user.id,
                    companyID: "", // We don't have company ID easily available here, but name/phone are more critical for this view
                    name: user.name,
                    employeeID: user.employeeId ?? "N/A",
                    phone: user.phone
                )
            }
            
            // Fetch Latest GPS Log
            let gpsResponse: [TripGPSLog] = try await SupabaseService.shared.client
                .from("trip_gps_logs")
                .select("*")
                .eq("trip_id", value: trip.id)
                .order("recorded_at", ascending: false)
                .limit(1)
                .execute()
                .value
            
            if let latest = gpsResponse.first {
                self.latestGPSLog = latest
            }
        } catch {
            print("🚨 TrackingShipmentViewModel Error: \(error)")
        }
    }
}
