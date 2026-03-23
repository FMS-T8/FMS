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

    // MARK: - Services
    public let locationManager: LocationManager
    private let pingService: LocationPingService
    private let dataSource: DriverDashboardDataSource

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
       public init(dataSource: DriverDashboardDataSource = MockDriverDashboardDataSource()) {
        self.dataSource = dataSource
        self.driver = dataSource.fetchCurrentDriver()
        self.assignedVehicle = dataSource.fetchAssignedVehicle()
        self.activeTrip = dataSource.fetchActiveTrip()
        self.upcomingTrips = dataSource.fetchUpcomingTrips()
        self.completedTrips = dataSource.fetchCompletedTrips()
        self.todayStats = dataSource.fetchTodayStats()
        
        // Add these to prevent "Return from initializer without initializing all stored properties" error!
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

            // Resume pinging if there is an active trip on app launch
            if let active = self.activeTrip {
                print("[DriverDashboard] Resuming active trip \(active.id) on launch — starting ping service")
                locationManager.startUpdating()
                pingService.start(tripId: active.id)
            }

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

    // MARK: - Lifecycle Actions
    public func startTrip(_ trip: Trip) {
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
            let image_urls: [String]?
        }

        // Upload photos first
        var uploadedUrls: [String] = []
        if let photos = report.photoData, !photos.isEmpty {
            let defectId = UUID().uuidString
            for (index, imageData) in photos.enumerated() {
                let path = "defects/\(defectId)/photo-\(index).jpg"

                try await SupabaseService.shared.client.storage
                    .from("report-issue-driver")
                    .upload(path, data: imageData, options: FileOptions(contentType: "image/jpeg"))

                let publicURL = try SupabaseService.shared.client.storage
                    .from("report-issue-driver")
                    .getPublicURL(path: path)

                uploadedUrls.append(publicURL.absoluteString)
            }
        }

        let payload = DefectCreatePayload(
            vehicle_id: report.vehicleId,
            reported_by: report.driverId,
            title: "\(report.category.rawValue) Issue",
            description: report.description,
            category: report.category.rawValue.lowercased(),
            priority: report.severity.rawValue.lowercased(),
            status: "open",
            image_urls: uploadedUrls.isEmpty ? nil : uploadedUrls
        )

        // Insert into DB
        try await SupabaseService.shared.client
            .from("defects")
            .insert(payload)
            .execute()

        // Trigger alerts
        SmartAlertService.shared.handleNewIssue(report)

        // Update UI
        self.issueReports.append(report)
    }

    /// Returns the string only if it's a valid UUID, otherwise nil.
    private func validUUID(_ string: String?) -> String? {
        guard let string, UUID(uuidString: string) != nil else { return nil }
        return string
    }


}

// MARK: - Protocol

public protocol DriverDashboardDataSource {
    func fetchCurrentDriver() -> DriverDisplayItem
    func fetchAssignedVehicle() -> Vehicle?
    func fetchActiveTrip() -> Trip?
    func fetchUpcomingTrips() -> [Trip]
    func fetchCompletedTrips() -> [Trip]
    func fetchTodayStats() -> DriverDayStats
}

// MARK: - Mock Data Source

public final class MockDriverDashboardDataSource: DriverDashboardDataSource {
    public nonisolated init() {}

    public func fetchCurrentDriver() -> DriverDisplayItem {
        let now = Date()
        return DriverDisplayItem(
            id: "drv-8821", name: "Alex Thompson", employeeID: "#DRV-8821",
            phone: "+91 98765 43210",
            vehicleId: "0254c00e-1aa5-430c-8069-4e0df7acaf9a", vehicleManufacturer: "Eicher", vehicleModel: "Pro 8055",
            plateNumber: "HR55XY1212",
            availabilityStatus: .onTrip,
            shiftStart: now.addingTimeInterval(-3 * 3600),
            shiftEnd: now.addingTimeInterval(5 * 3600),
            activeTripId: "trip-101"
        )
    }

    public func fetchAssignedVehicle() -> Vehicle? {
        Vehicle(
            id: "0254c00e-1aa5-430c-8069-4e0df7acaf9a",
            plateNumber: "HR55XY1212",
            chassisNumber: "V445566",
            manufacturer: "Eicher",
            model: "Pro 8055",
            fuelType: "Diesel",
            fuelTankCapacity: 300,
            odometer: 15_600,
            status: "active"
        )
    }

    public func fetchActiveTrip() -> Trip? {
        Trip(
            id: "trip-101",
            vehicleId: "0254c00e-1aa5-430c-8069-4e0df7acaf9a",
            driverId: "drv-8821",
            shipmentDescription: "Electronics consignment",
            shipmentWeightKg: 2400,
            shipmentPackageCount: 48,
            fragile: true,
            startLat: 19.0760,
            startLng: 72.8777,
            startName: "Mumbai Warehouse",
            endLat: 18.5204,
            endLng: 73.8567,
            endName: "Pune Distribution Center",
            distanceKm: 148,
            estimatedDurationMinutes: 210,
            status: "active",
            startTime: Date().addingTimeInterval(-2 * 3600)
        )
    }

    public func fetchUpcomingTrips() -> [Trip] {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        let dayAfter = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: Date()))!
        let threeDays = calendar.date(byAdding: .day, value: 3, to: calendar.startOfDay(for: Date()))!
        let fourDays = calendar.date(byAdding: .day, value: 4, to: calendar.startOfDay(for: Date()))!
        let fiveDays = calendar.date(byAdding: .day, value: 5, to: calendar.startOfDay(for: Date()))!
        let sixDays = calendar.date(byAdding: .day, value: 6, to: calendar.startOfDay(for: Date()))!

        return [
            Trip(
                id: "trip-102", vehicleId: "0254c00e-1aa5-430c-8069-4e0df7acaf9a", driverId: "drv-8821",
                shipmentDescription: "Textile shipment",
                startLat: 19.0760, startLng: 72.8777,
                startName: "Mumbai Warehouse",
                endLat: 19.9975, endLng: 73.7898,
                endName: "Nashik Hub",
                distanceKm: 167, estimatedDurationMinutes: 250,
                status: "scheduled",
                startTime: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: tomorrow)
            ),
            Trip(
                id: "trip-103", vehicleId: "0254c00e-1aa5-430c-8069-4e0df7acaf9a", driverId: "drv-8821",
                shipmentDescription: "FMCG delivery",
                startLat: 19.0760, startLng: 72.8777,
                startName: "Mumbai Warehouse",
                endLat: 16.7050, endLng: 74.2433,
                endName: "Kolhapur Depot",
                distanceKm: 230, estimatedDurationMinutes: 330,
                status: "scheduled",
                startTime: calendar.date(bySettingHour: 7, minute: 30, second: 0, of: dayAfter)
            ),
            Trip(
                id: "trip-104", vehicleId: "0254c00e-1aa5-430c-8069-4e0df7acaf9a", driverId: "drv-8821",
                shipmentDescription: "Auto parts",
                startLat: 19.0760, startLng: 72.8777,
                startName: "Mumbai Warehouse",
                endLat: 19.8762, endLng: 75.3433,
                endName: "Aurangabad Center",
                distanceKm: 335, estimatedDurationMinutes: 420,
                status: "scheduled",
                startTime: calendar.date(bySettingHour: 6, minute: 0, second: 0, of: threeDays)
            ),
            Trip(
                id: "trip-105", vehicleId: "0254c00e-1aa5-430c-8069-4e0df7acaf9a", driverId: "drv-8821",
                shipmentDescription: "Pharmaceutical supplies",
                startLat: 19.0760, startLng: 72.8777,
                startName: "Mumbai Warehouse",
                endLat: 21.1458, endLng: 79.0882,
                endName: "Nagpur Distribution Hub",
                distanceKm: 810, estimatedDurationMinutes: 720,
                status: "scheduled",
                startTime: calendar.date(bySettingHour: 5, minute: 0, second: 0, of: fourDays)
            ),
            Trip(
                id: "trip-106", vehicleId: "0254c00e-1aa5-430c-8069-4e0df7acaf9a", driverId: "drv-8821",
                shipmentDescription: "Steel coils",
                startLat: 19.9975, startLng: 73.7898,
                startName: "Nashik Hub",
                endLat: 21.1702, endLng: 72.8311,
                endName: "Surat Terminal",
                distanceKm: 260, estimatedDurationMinutes: 310,
                status: "scheduled",
                startTime: calendar.date(bySettingHour: 7, minute: 0, second: 0, of: fiveDays)
            ),
            Trip(
                id: "trip-107", vehicleId: "0254c00e-1aa5-430c-8069-4e0df7acaf9a", driverId: "drv-8821",
                shipmentDescription: "Food grains",
                startLat: 18.5204, startLng: 73.8567,
                startName: "Pune Distribution Center",
                endLat: 15.2993, endLng: 74.1240,
                endName: "Goa Warehouse",
                distanceKm: 450, estimatedDurationMinutes: 480,
                status: "scheduled",
                startTime: calendar.date(bySettingHour: 6, minute: 30, second: 0, of: sixDays)
            ),
        ]
    }

    public func fetchCompletedTrips() -> [Trip] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return [
            Trip(
                id: "trip-095", vehicleId: "0254c00e-1aa5-430c-8069-4e0df7acaf9a", driverId: "drv-8821",
                startName: "Mumbai Warehouse", endName: "Pune Distribution Center",
                distanceKm: 148, actualDurationMinutes: 200,
                status: "completed",
                startTime: calendar.date(byAdding: .day, value: -1, to: today)!.addingTimeInterval(8 * 3600),
                endTime: calendar.date(byAdding: .day, value: -1, to: today)!.addingTimeInterval(11.33 * 3600)
            ),
            Trip(
                id: "trip-091", vehicleId: "0254c00e-1aa5-430c-8069-4e0df7acaf9a", driverId: "drv-8821",
                startName: "Pune Distribution Center", endName: "Mumbai Warehouse",
                distanceKm: 150, actualDurationMinutes: 225,
                status: "completed",
                startTime: calendar.date(byAdding: .day, value: -2, to: today)!.addingTimeInterval(9 * 3600),
                endTime: calendar.date(byAdding: .day, value: -2, to: today)!.addingTimeInterval(12.75 * 3600)
            ),
            Trip(
                id: "trip-088", vehicleId: "0254c00e-1aa5-430c-8069-4e0df7acaf9a", driverId: "drv-8821",
                startName: "Mumbai Warehouse", endName: "Nashik Hub",
                distanceKm: 167, actualDurationMinutes: 250,
                status: "completed",
                startTime: calendar.date(byAdding: .day, value: -3, to: today)!.addingTimeInterval(7 * 3600),
                endTime: calendar.date(byAdding: .day, value: -3, to: today)!.addingTimeInterval(11.17 * 3600)
            ),
            Trip(
                id: "trip-085", vehicleId: "0254c00e-1aa5-430c-8069-4e0df7acaf9a", driverId: "drv-8821",
                startName: "Nashik Hub", endName: "Mumbai Warehouse",
                distanceKm: 170, actualDurationMinutes: 270,
                status: "completed",
                startTime: calendar.date(byAdding: .day, value: -4, to: today)!.addingTimeInterval(8 * 3600),
                endTime: calendar.date(byAdding: .day, value: -4, to: today)!.addingTimeInterval(12.5 * 3600)
            ),
            Trip(
                id: "trip-080", vehicleId: "0254c00e-1aa5-430c-8069-4e0df7acaf9a", driverId: "drv-8821",
                startName: "Mumbai Warehouse", endName: "Surat Terminal",
                distanceKm: 284, actualDurationMinutes: 375,
                status: "completed",
                startTime: calendar.date(byAdding: .day, value: -7, to: today)!.addingTimeInterval(6 * 3600),
                endTime: calendar.date(byAdding: .day, value: -7, to: today)!.addingTimeInterval(12.25 * 3600)
            ),
        ]
    }

   public func fetchTodayStats() -> DriverDayStats {
    return DriverDayStats(
        tripsCompleted: 2,
        totalDistanceKm: 298,
        drivingTimeMinutes: 425
    )
    }
}
