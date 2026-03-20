//
//  DriverDashboardViewModel.swift
//  FMS
//

import Foundation
import Observation
import Supabase

// MARK: - Driver Day Stats
public struct DriverDayStats {
    public var tripsCompleted: Int
    public var totalDistanceKm: Double
    public var drivingTimeMinutes: Int

    public var formattedDistance: String { String(format: "%.0f km", totalDistanceKm) }
    public var formattedDrivingTime: String {
        let hours = drivingTimeMinutes / 60
        let minutes = drivingTimeMinutes % 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - UI Enums
public enum TripFilterOption: String, CaseIterable {
    case all = "All", today = "Today", thisWeek = "This Week", thisMonth = "This Month"
}

public enum TripSegment: String, CaseIterable {
    case upcoming = "Upcoming", history = "History"
}

@MainActor
@Observable
public final class DriverDashboardViewModel {

    // MARK: - Identity
    public var driver: DriverDisplayItem
    public var assignedVehicle: Vehicle?

    // MARK: - Trip State
    public var activeTrip: Trip?
    public var upcomingTrips: [Trip] = []
    public var completedTrips: [Trip] = []

    // MARK: - Stats
    public var todayStats: DriverDayStats

    // MARK: - UI State
    public var isLoading: Bool = false
    public var searchText: String = ""
    public var selectedTripFilter: TripFilterOption = .all
    public var selectedSegment: TripSegment = .upcoming
    public var issueReports: [IssueReport] = []
    public var errorMessage: String? = nil

    // MARK: - Computed
    public var hasActiveTrip: Bool { activeTrip != nil }
    public var currentJob: Trip? { activeTrip ?? upcomingTrips.first }
    public var currentJobIsActive: Bool { activeTrip != nil }

    public var remainingUpcomingTrips: [Trip] {
        if activeTrip != nil { return upcomingTrips } else { return Array(upcomingTrips.dropFirst()) }
    }

    public var filteredCompletedTrips: [Trip] {
        var trips = completedTrips
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            trips = trips.filter { trip in
                (trip.startName?.lowercased().contains(query) ?? false) ||
                (trip.endName?.lowercased().contains(query) ?? false) ||
                trip.id.lowercased().contains(query)
            }
        }
        return trips
    }

    public var activeTripElapsedTime: String {
        guard let trip = activeTrip, let start = trip.startTime else { return "--" }
        let interval = Date().timeIntervalSince(start)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    public var activeTripRoute: String {
        guard let trip = activeTrip else { return "" }
        return "\(trip.startName ?? "Origin") → \(trip.endName ?? "Destination")"
    }

    // MARK: - Init
    public init() {
        self.driver = DriverDisplayItem(id: "", name: "Loading...", employeeID: "", phone: "", availabilityStatus: .offDuty)
        self.todayStats = DriverDayStats(tripsCompleted: 0, totalDistanceKm: 0, drivingTimeMinutes: 0)
    }

    // MARK: - Live Data Fetch
    public func fetchLiveDashboardData() async {
        self.isLoading = true
        self.errorMessage = nil
        do {
            let session = try await SupabaseService.shared.client.auth.session
            let currentUserId = session.user.id.uuidString

            struct UserProfile: Decodable { let id: String; let name: String; let phone: String?; let operational_status: String? }
            let profiles: [UserProfile] = try await SupabaseService.shared.client
                .from("users")
                .select("id, name, phone, operational_status")
                .eq("id", value: currentUserId)
                .execute()
                .value

            if let p = profiles.first {
                let currentStatus: DriverAvailabilityStatus = (p.operational_status == "on_trip") ? .onTrip : (p.operational_status == "available" ? .available : .offDuty)
                self.driver = DriverDisplayItem(id: p.id, name: p.name, employeeID: "DRV-\(p.id.prefix(4).uppercased())", phone: p.phone ?? "N/A", availabilityStatus: currentStatus)
            }

            let allTrips: [Trip] = try await SupabaseService.shared.client
                .from("trips")
                .select("*")
                .eq("driver_id", value: currentUserId)
                .order("created_at", ascending: false)
                .execute()
                .value

            let activeStatuses = ["active", "in_progress", "in_transit"]
            let upcomingStatuses = ["pending", "scheduled", "assigned"]
            let completedStatuses = ["completed", "delivered", "cancelled"]

            self.activeTrip = allTrips.first(where: { activeStatuses.contains($0.status?.lowercased() ?? "") })
            
            self.upcomingTrips = allTrips.filter { upcomingStatuses.contains($0.status?.lowercased() ?? "") }
                .sorted { ($0.startTime ?? Date.distantFuture) < ($1.startTime ?? Date.distantFuture) }
            
            self.completedTrips = allTrips.filter { completedStatuses.contains($0.status?.lowercased() ?? "") }
                .sorted { ($0.endTime ?? Date.distantPast) > ($1.endTime ?? Date.distantPast) }

            if let vehicleId = activeTrip?.vehicleId ?? upcomingTrips.first?.vehicleId {
                let vehicles: [Vehicle] = try await SupabaseService.shared.client
                    .from("vehicles")
                    .select()
                    .eq("id", value: vehicleId)
                    .execute()
                    .value
                self.assignedVehicle = vehicles.first
            }

            self.todayStats.tripsCompleted = self.completedTrips.count

        } catch {
            print("Failed to fetch driver dashboard: \(error)")
            self.errorMessage = error.localizedDescription
        }
        self.isLoading = false
    }

    // MARK: - Lifecycle Actions (Syncing with DB!)
    public func startTrip(_ trip: Trip) {
        var started = trip
        started.status = "active"
        started.startTime = Date()
        self.activeTrip = started
        self.upcomingTrips.removeAll { $0.id == trip.id }
        self.driver.availabilityStatus = .onTrip

        Task {
            do {
                struct TripUpdate: Encodable { let status: String }
                try await SupabaseService.shared.client.from("trips").update(TripUpdate(status: "active")).eq("id", value: trip.id).execute()
                
                struct UserUpdate: Encodable { let operational_status: String }
                try await SupabaseService.shared.client.from("users").update(UserUpdate(operational_status: "on_trip")).eq("id", value: driver.id).execute()
                
                if let orderId = trip.orderId {
                    struct OrderUpdate: Encodable { let status: String }
                    try await SupabaseService.shared.client.from("orders").update(OrderUpdate(status: "in_transit")).eq("id", value: orderId).execute()
                }
            } catch { print("Failed to start trip in DB: \(error)") }
        }
    }

    public func endTrip() {
        guard var trip = activeTrip else { return }
        
        trip.status = "completed"
        trip.endTime = Date()
        self.completedTrips.insert(trip, at: 0)
        self.activeTrip = nil
        self.todayStats.tripsCompleted += 1
        self.driver.availabilityStatus = .available

        Task {
            do {
                struct TripUpdate: Encodable { let status: String }
                try await SupabaseService.shared.client.from("trips").update(TripUpdate(status: "completed")).eq("id", value: trip.id).execute()
                
                if let orderId = trip.orderId {
                    struct OrderUpdate: Encodable { let status: String }
                    try await SupabaseService.shared.client.from("orders").update(OrderUpdate(status: "delivered")).eq("id", value: orderId).execute()
                }
                
                struct UserUpdate: Encodable { let operational_status: String }
                try await SupabaseService.shared.client.from("users").update(UserUpdate(operational_status: "available")).eq("id", value: driver.id).execute()
                
            } catch { print("Failed to complete trip in DB: \(error)") }
        }
    }
    
    // MARK: - Issue Reporting Sync
    public func submitIssueReport(_ report: IssueReport) async throws {
        struct DefectCreatePayload: Encodable {
            let vehicle_id: String?
            let reported_by: String?   // <--- FIX: Made Optional
            let title: String
            let description: String?   // <--- FIX: Made Optional
            let category: String
            let priority: String
            let status: String
        }
        
        let payload = DefectCreatePayload(
            vehicle_id: report.vehicleId,
            reported_by: report.driverId,
            title: "Driver Issue Report: \(report.category.rawValue)",
            description: report.description,
            category: report.category.rawValue.lowercased(),
            priority: report.severity.rawValue.lowercased(),
            status: "open"
        )
        
        try await SupabaseService.shared.client
            .from("defects")
            .insert(payload)
            .execute()
    }
}
