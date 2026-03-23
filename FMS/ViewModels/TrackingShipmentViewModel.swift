//
//  TrackingShipmentViewModel.swift
//  FMS
//
//  Created by Anish on 12/03/26.
//

import Foundation
import Observation
import CoreLocation

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
    public var formattedEstimatedDate: String {
        guard let durationMin = trip?.estimatedDurationMinutes,
              let startTime = trip?.startTime else { return "Calculating..." }
        
        let estimatedEnd = startTime.addingTimeInterval(TimeInterval(durationMin * 60))
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter.string(from: estimatedEnd)
    }
    
    // Temporary initializer with mock data mapped to your REAL models for UI testing
    public init() {
        self.trip = Trip(
            id: "TRP-8492-MH",
            shipmentDescription: "Electronics",
            startLat: 12.35,
            startLng: 76.65,
            startName: "Warehouse A, Industrial Layout, Mysuru",
            endLat: 12.84,
            endLng: 77.66,
            endName: "Tech Park Phase 2, Electronic City, Bengaluru",
            estimatedDurationMinutes: 180,
            startTime: Date()
        )
        self.driver = Driver(companyID: "CMP-01", name: "David Reynolds", employeeID: "EMP-492")
        self.vehicle = Vehicle(id: "V-01", plateNumber: "MH02H0942", chassisNumber: "CHS123", fuelType: "Diesel", fuelTankCapacity: 200, createdAt: Date())
        self.latestGPSLog = TripGPSLog(id: "LOG-1", tripId: "TRP-8492-MH", lat: 12.35, lng: 76.65, speed: 45, recordedAt: Date())
    }
}
