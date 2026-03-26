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
    public var alerts: [Notification] = []

    // MARK: - Stats
    public var todayStats: DriverDayStats

    // MARK: - Services
    public let locationManager: LocationManager
    private let pingService: LocationPingService

    // MARK: - UI State
    public var isLoading: Bool = false
    public var searchText: String = ""
    public var selectedTripFilter: TripFilterOption = .all
    public var selectedSegment: TripSegment = .upcoming
    public var issueReports: [IssueReport] = []
    public var errorMessage: String? = nil

    // MARK: - Break Logging
    public var breakLogViewModel: BreakLogViewModel = BreakLogViewModel()

    // MARK: - Computed
    public var hasActiveTrip: Bool { activeTrip != nil }
    public var currentJob: Trip? { activeTrip ?? upcomingTrips.first }
    public var currentJobIsActive: Bool { activeTrip != nil }

    public var remainingUpcomingTrips: [Trip] {
        if activeTrip != nil { return upcomingTrips } else { return Array(upcomingTrips.dropFirst()) }
    }

    public var filteredCompletedTrips: [Trip] {
        let calendar = Calendar.current
        let now = Date()

        var trips = completedTrips.filter { trip in
            guard let date = trip.startTime else {
                return selectedTripFilter == .all
            }
            switch selectedTripFilter {
            case .all:       return true
            case .today:     return calendar.isDateInToday(date)
            case .thisWeek:  return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
            case .thisMonth: return calendar.isDate(date, equalTo: now, toGranularity: .month)
            }
        }

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
        let lm = LocationManager()
        self.locationManager = lm
        self.pingService = LocationPingService(locationManager: lm)
    }

    // MARK: - Live Data Fetch
    public func fetchLiveDashboardData() async {
        self.isLoading = true
        self.errorMessage = nil
        locationManager.requestWhenInUsePermission()
        do {
            let session = try await SupabaseService.shared.client.auth.session
            let currentUserId = session.user.id.uuidString

            struct UserProfile: Decodable {
                let id: String
                let name: String
                let phone: String?
                let operational_status: String?
            }
            let profiles: [UserProfile] = try await SupabaseService.shared.client
                .from("users")
                .select("id, name, phone, operational_status")
                .eq("id", value: currentUserId)
                .execute()
                .value

            if let p = profiles.first {
                let currentStatus: DriverAvailabilityStatus =
                    p.operational_status == "on_trip"  ? .onTrip  :
                    p.operational_status == "available" ? .available : .offDuty
                self.driver = DriverDisplayItem(
                    id: p.id,
                    name: p.name,
                    employeeID: "DRV-\(p.id.prefix(4).uppercased())",
                    phone: p.phone ?? "N/A",
                    availabilityStatus: currentStatus
                )
                
                // Fetch break logs explicitly for this driver — moved below activeTrip determination
            }

            let allTrips: [Trip] = try await SupabaseService.shared.client
                .from("trips")
                .select("*")
                .eq("driver_id", value: currentUserId)
                .order("created_at", ascending: false)
                .execute()
                .value

            let activeStatuses    = ["active", "in_progress", "in_transit"]
            let upcomingStatuses  = ["pending", "scheduled", "assigned", "confirmed"]
            let completedStatuses = ["completed", "delivered", "cancelled"]

            self.activeTrip = allTrips.first(where: { activeStatuses.contains($0.status?.lowercased() ?? "") })
            self.upcomingTrips = allTrips
                .filter { upcomingStatuses.contains($0.status?.lowercased() ?? "") }
                .sorted { ($0.startTime ?? Date.distantFuture) < ($1.startTime ?? Date.distantFuture) }
            self.completedTrips = allTrips
                .filter { completedStatuses.contains($0.status?.lowercased() ?? "") }
                .sorted { ($0.endTime ?? Date.distantPast) > ($1.endTime ?? Date.distantPast) }

            if let active = self.activeTrip {
                print("[DriverDashboard] Resuming active trip \(active.id) on launch — starting ping service")
                locationManager.startUpdating()
                pingService.start(tripId: active.id)
            }

            // Fetch break logs explicitly for this driver, scoped to the active trip if available
            await self.breakLogViewModel.loadBreaks(driverId: currentUserId, tripId: self.activeTrip?.id)

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
            
            if let jobId = self.currentJob?.id {
                await fetchAlerts(tripId: jobId)
            } else {
                self.alerts = []
            }

        } catch {
            print("Failed to fetch driver dashboard: \(error)")
            self.alerts = []
            self.errorMessage = error.localizedDescription
        }
        self.isLoading = false
    }

    // MARK: - Lifecycle Actions
    public func startTrip(_ trip: Trip) {
        // Prevent starting a new trip if one is already active
        guard activeTrip == nil else {
            self.errorMessage = "You already have an active trip. Please complete it before starting a new one."
            print("[DriverDashboard] Blocking startTrip: Another trip (\(activeTrip?.id ?? "")) is already active")
            return
        }

        var started = trip
        started.status = "active"
        started.startTime = Date()
        self.activeTrip = started
        self.upcomingTrips.removeAll { $0.id == trip.id }

        Task {
            do {
                struct TripUpdate: Encodable {
                    let status: String
                    let start_time: Date
                }
                let update = TripUpdate(status: "active", start_time: started.startTime ?? Date())
                try await SupabaseService.shared.client
                    .from("trips").update(update).eq("id", value: trip.id).execute()

                print("[DriverDashboard] Trip persisted as active — starting location updates and ping service")
                locationManager.startUpdating()
                pingService.start(tripId: trip.id)

                struct UserUpdate: Encodable { let operational_status: String }
                try await SupabaseService.shared.client
                    .from("users").update(UserUpdate(operational_status: "on_trip")).eq("id", value: driver.id).execute()
                
                self.driver.availabilityStatus = .onTrip

                if let orderId = trip.orderId {
                    struct OrderUpdate: Encodable { let status: String }
                    try await SupabaseService.shared.client
                        .from("orders").update(OrderUpdate(status: "in_transit")).eq("id", value: orderId).execute()
                }
            } catch {
                print("Failed to start trip in DB: \(error)")
                locationManager.stopUpdating()
                pingService.stop()
            }
        }
    }

    public func endTrip() {
        guard var trip = activeTrip else { return }

        trip.endTime = Date()
        self.completedTrips.insert(trip, at: 0)
        self.activeTrip = nil
        self.todayStats.tripsCompleted += 1

        Task {
            do {
                let endTime = trip.endTime ?? Date()
                let duration: Int? = if let start = trip.startTime {
                    Int(endTime.timeIntervalSince(start) / 60)
                } else { nil }

                struct TripUpdate: Encodable {
                    let status: String
                    let end_time: Date
                    let actual_duration_minutes: Int?
                }
                let update = TripUpdate(
                    status: "completed",
                    end_time: endTime,
                    actual_duration_minutes: duration
                )
                try await SupabaseService.shared.client
                    .from("trips").update(update).eq("id", value: trip.id).execute()

                print("[DriverDashboard] Trip persisted as completed — stopping ping service")
                
                // Ensure any active break is also ended when the trip is completed
                self.breakLogViewModel.endBreak()

                pingService.stop()
                locationManager.stopUpdating()

                if let orderId = trip.orderId {
                    struct OrderUpdate: Encodable { let status: String }
                    try await SupabaseService.shared.client
                        .from("orders").update(OrderUpdate(status: "delivered")).eq("id", value: orderId).execute()
                }

                struct UserUpdate: Encodable { let operational_status: String }
                try await SupabaseService.shared.client
                    .from("users").update(UserUpdate(operational_status: "available")).eq("id", value: driver.id).execute()
                
                // Update local status after successful backend write
                self.driver.availabilityStatus = .available

            } catch {
                print("Failed to complete trip in DB: \(error)")
                // If fail, we still likely want to stop tracking as the driver thinks it's ended
                pingService.stop()
                locationManager.stopUpdating()
            }
        }
    }

    // MARK: - Issue Reporting
    public func submitIssueReport(_ report: IssueReport) async throws {
        struct DefectCreatePayload: Encodable {
            let vehicle_id: String?
            let reported_by: String?
            let title: String
            let description: String?
            let category: String
            let priority: String
            let status: String
        }

        let payload = DefectCreatePayload(
            vehicle_id:   report.vehicleId,
            reported_by:  report.driverId,
            title:        "Driver Issue Report: \(report.category.rawValue)",
            description:  report.description,
            category:     report.category.rawValue.lowercased(),
            priority:     report.severity.rawValue.lowercased(),
            status:       "open"
        )

        try await SupabaseService.shared.client
            .from("defects")
            .insert(payload)
            .execute()

        // Append to local array immediately after a successful DB insert so any
        // observing view reflects the new report without a full refresh.
        // issueReports holds IssueReport (the domain model), not DefectCreatePayload,
        // so the types remain consistent with all existing call sites.
        self.issueReports.append(report)
    }

    // MARK: - Alerts
    public func fetchAlerts(tripId: String) async {
        do {
            let results: [Notification] = try await SupabaseService.shared.client
                .from("notifications")
                .select("*")
                .eq("trip_id", value: tripId)
                .order("created_at", ascending: false)
                .execute()
                .value

            self.alerts = results
        } catch {
            print("[DriverDashboard] Failed to fetch alerts: \(error)")
        }
    }
}
