//
//  LocationPingService.swift
//  FMS
//
//  Created by Nikunj Mathur on 22/03/26.
//  Pings the driver's current location to `trip_gps_logs` every 10 seconds
//  while a trip is active. Owned exclusively by DriverDashboardViewModel.
//

import Foundation
import CoreLocation
import Supabase

@Observable
@MainActor
public final class LocationPingService {

    // MARK: - State
    private(set) var isRunning = false
    private(set) var tripId: String?
    private(set) var lastPingAt: Date?
    private(set) var pingCount: Int = 0
    private var isPinging = false

    // MARK: - Private
    private var locationManager: LocationManager
    private var pingTask: Task<Void, Never>?

    /// Interval between location pings (seconds). 10 for demo.
    private let pingInterval: TimeInterval = 10

    // MARK: - Init
    public init(locationManager: LocationManager) {
        self.locationManager = locationManager
    }

    // MARK: - Control

    /// Begin pinging for the given trip.
    public func start(tripId: String) {
        if isRunning {
            if self.tripId == tripId {
                print("[LocationPingService] Already running for trip \(tripId), continuing.")
                return
            } else {
                print("[LocationPingService] ⚠️ Switching from \(self.tripId ?? "nil") to \(tripId)")
                stop()
            }
        }
        
        self.tripId = tripId
        self.isRunning = true
        self.pingCount = 0
        print("[LocationPingService] ✅ Started pinging for trip \(tripId)")
        
        // Ensure location manager is updating
        locationManager.startUpdating()
        
        startObservation()
    }

    /// Stop pinging and cancel the observation task.
    public func stop() {
        pingTask?.cancel()
        pingTask = nil
        print("[LocationPingService] 🛑 Stopped pinging for trip \(tripId ?? "nil") after \(pingCount) pings")
        isRunning = false
        tripId = nil
    }

    // MARK: - Private helpers

    private func startObservation() {
        pingTask?.cancel()
        
        pingTask = Task {
            // Immediate first ping
            await pingLocation()
            
            // Listen for location updates from manager
            for await location in locationManager.locationUpdates() {
                if Task.isCancelled { break }
                
                // Respect pingInterval
                let now = Date()
                if let last = lastPingAt, now.timeIntervalSince(last) < pingInterval {
                    continue
                }
                
                #if DEBUG
                print("[LocationPingService] 📥 Received location update from stream, triggering ping")
                #endif
                await pingLocation(location)
            }
        }
    }

    private func pingLocation(_ specificLocation: CLLocation? = nil) async {
        guard !isPinging else {
            #if DEBUG
            print("[LocationPingService] ⏳ Ping already in progress, skipping overlap")
            #endif
            return
        }
        
        isPinging = true
        defer { isPinging = false }

        guard let tripId else {
            print("[LocationPingService] ⚠️ No active tripId, skipping ping")
            return
        }

        guard let location = specificLocation ?? locationManager.currentLocation else {
            print("[LocationPingService] ⚠️ No location yet. Skipping ping #\(pingCount + 1).")
            return
        }

        let age = Date().timeIntervalSince(location.timestamp)
        guard age <= pingInterval * 2 else {
            print("[LocationPingService] ⚠️ Stale location fix (\(Int(age))s old), skipping ping")
            return
        }

        struct GPSLogInsert: Encodable {
            let trip_id: String
            let lat: Double
            let lng: Double
            let speed: Double?
            let heading: Double?
        }

        let payload = GPSLogInsert(
            trip_id: tripId,
            lat: location.coordinate.latitude,
            lng: location.coordinate.longitude,
            speed: location.speed >= 0 ? location.speed : nil,
            heading: location.course >= 0 ? location.course : nil
        )

        #if DEBUG
        print("[LocationPingService] 📡 Sending ping to Supabase: \(payload.lat), \(payload.lng) for trip \(tripId)")
        #endif

        do {
            let response = try await SupabaseService.shared.client
                .from("trip_gps_logs")
                .insert(payload)
                .execute()
            
            pingCount += 1
            self.lastPingAt = Date()
            print("[LocationPingService] 📍 Success Ping #\(pingCount) (Status: \(response.status))")
        } catch {
            print("[LocationPingService] ❌ Supabase Insert Error: \(error)")
        }
    }
}
