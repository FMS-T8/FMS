import Foundation
import Observation
import Supabase

// MARK: - Driver Day Stats

public struct DriverDayStats {
    public var tripsCompleted: Int
    public var totalDistanceKm: Double
    public var drivingTimeMinutes: Int

    public var formattedDistance: String {
        String(format: "%.0f km", totalDistanceKm)
    }

    public var formattedDrivingTime: String {
        let hours = drivingTimeMinutes / 60
        let minutes = drivingTimeMinutes % 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Trip Filter

public enum TripFilterOption: String, CaseIterable {
    case all = "All"
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
}

// MARK: - Trip Segment

public enum TripSegment: String, CaseIterable {
    case upcoming = "Upcoming"
    case history = "History"
}

// MARK: - Data Source Protocol

@MainActor
public protocol DriverDashboardDataSource {
    func fetchCurrentDriver() -> DriverDisplayItem
    func fetchAssignedVehicle() -> Vehicle?
    func fetchActiveTrip() -> Trip?
    func fetchUpcomingTrips() -> [Trip]
    func fetchCompletedTrips() -> [Trip]
    func fetchTodayStats() -> DriverDayStats
}

// MARK: - ViewModel

@MainActor
@Observable
public final class DriverDashboardViewModel {

    // MARK: - Identity
    public var driver: DriverDisplayItem
    public var assignedVehicle: Vehicle?

    // MARK: - Trip State
    public var activeTrip: Trip?
    public var upcomingTrips: [Trip]
    public var completedTrips: [Trip]

    // MARK: - Stats
    public var todayStats: DriverDayStats

    // MARK: - UI State
    public var isLoading: Bool = false
    public var searchText: String = ""
    public var selectedTripFilter: TripFilterOption = .all
    public var selectedSegment: TripSegment = .upcoming
    public var issueReports: [IssueReport] = []

    // MARK: - Computed

    public var hasActiveTrip: Bool { activeTrip != nil }

    /// The current job: active trip, or the next upcoming trip
    public var currentJob: Trip? {
        activeTrip ?? upcomingTrips.first
    }

    /// Whether the current job is an active (in-progress) trip
    public var currentJobIsActive: Bool {
        activeTrip != nil
    }

    /// Upcoming trips excluding the one shown as current job
    public var remainingUpcomingTrips: [Trip] {
        if activeTrip != nil {
            return upcomingTrips
        } else {
            return Array(upcomingTrips.dropFirst())
        }
    }

    public var filteredCompletedTrips: [Trip] {
        var trips = completedTrips

        // Search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            trips = trips.filter { trip in
                (trip.startName?.lowercased().contains(query) ?? false) ||
                (trip.endName?.lowercased().contains(query) ?? false) ||
                trip.id.lowercased().contains(query)
            }
        }

        // Date filter
        let calendar = Calendar.current
        let now = Date()
        switch selectedTripFilter {
        case .all:
            break
        case .today:
            trips = trips.filter { trip in
                guard let date = trip.endTime ?? trip.startTime else { return false }
                return calendar.isDateInToday(date)
            }
        case .thisWeek:
            trips = trips.filter { trip in
                guard let date = trip.endTime ?? trip.startTime else { return false }
                return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
            }
        case .thisMonth:
            trips = trips.filter { trip in
                guard let date = trip.endTime ?? trip.startTime else { return false }
                return calendar.isDate(date, equalTo: now, toGranularity: .month)
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
        let from = trip.startName ?? "Origin"
        let to = trip.endName ?? "Destination"
        return "\(from) → \(to)"
    }

    // MARK: - Actions

    public func startTrip(_ trip: Trip) {
        var started = trip
        started.status = "active"
        started.startTime = Date()
        activeTrip = started
        upcomingTrips.removeAll { $0.id == trip.id }
    }

    public func endTrip() {
        guard var trip = activeTrip else { return }
        trip.status = "completed"
        trip.endTime = Date()
        completedTrips.insert(trip, at: 0)
        activeTrip = nil
        todayStats.tripsCompleted += 1
    }

    public func submitIssueReport(_ report: IssueReport) async throws {
        // Map IssueCategory to DB enum values
        let categoryMapping: [IssueCategory: String] = [
            .engine: "engine", .brakes: "brakes", .tires: "tires",
            .electrical: "electrical", .body: "body_damage", .other: "other"
        ]
        // Map IssueSeverity to DB enum values
        let priorityMapping: [IssueSeverity: String] = [
            .low: "low", .medium: "medium", .high: "high", .critical: "critical"
        ]

        // Only send FK fields that are valid UUIDs — mock IDs will cause FK violations
        var vehicleId = validUUID(report.vehicleId) ?? validUUID(assignedVehicle?.id)
        let reportedBy = validUUID(report.driverId)
        let tripId = validUUID(report.tripId)

        // Mock vehicle IDs aren't valid UUIDs — resolve by matching plate number in DB
        if vehicleId == nil, let plate = assignedVehicle?.plateNumber {
            let resp = try await SupabaseService.shared.client
                .from("vehicles")
                .select("id")
                .eq("plate_number", value: plate)
                .limit(1)
                .execute()
            if let first = try? JSONDecoder().decode([[String: String]].self, from: resp.data).first {
                vehicleId = first["id"]
            }
        }

        guard let resolvedVehicleId = vehicleId else {
            throw NSError(domain: "FMS", code: 1, userInfo: [NSLocalizedDescriptionKey: "No assigned vehicle found. Please ensure a vehicle is assigned before reporting an issue."])
        }

        let title = "\(report.category.rawValue) Issue"
            + (report.description.isEmpty ? "" : " – \(report.description.prefix(60))")

        // Upload photos to storage and collect public URLs
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

        let defect = DefectInsert(
            id: report.id,
            vehicleId: resolvedVehicleId,
            reportedBy: reportedBy,
            tripId: tripId,
            title: title,
            description: report.description,
            category: categoryMapping[report.category] ?? "other",
            priority: priorityMapping[report.severity] ?? "medium",
            status: "open",
            reportedAt: Date(),
            imageUrls: uploadedUrls.isEmpty ? nil : uploadedUrls
        )

        try await SupabaseService.shared.client
            .from("defects")
            .insert(defect)
            .execute()

        // Trigger Smart Alert System logic
        SmartAlertService.shared.handleNewIssue(report)

        issueReports.append(report)
    }

    /// Returns the string only if it's a valid UUID, otherwise nil.
    private func validUUID(_ string: String?) -> String? {
        guard let string, UUID(uuidString: string) != nil else { return nil }
        return string
    }

    // MARK: - Init

    private let dataSource: DriverDashboardDataSource

    public init(dataSource: DriverDashboardDataSource = MockDriverDashboardDataSource()) {
        self.dataSource = dataSource
        self.driver = dataSource.fetchCurrentDriver()
        self.assignedVehicle = dataSource.fetchAssignedVehicle()
        self.activeTrip = dataSource.fetchActiveTrip()
        self.upcomingTrips = dataSource.fetchUpcomingTrips()
        self.completedTrips = dataSource.fetchCompletedTrips()
        self.todayStats = dataSource.fetchTodayStats()
    }
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
            estimatedDurationMin: 210,
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
                distanceKm: 167, estimatedDurationMin: 250,
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
                distanceKm: 230, estimatedDurationMin: 330,
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
                distanceKm: 335, estimatedDurationMin: 420,
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
                distanceKm: 810, estimatedDurationMin: 720,
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
                distanceKm: 260, estimatedDurationMin: 310,
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
                distanceKm: 450, estimatedDurationMin: 480,
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
                distanceKm: 148, actualDurationMin: 200,
                status: "completed",
                startTime: calendar.date(byAdding: .day, value: -1, to: today)!.addingTimeInterval(8 * 3600),
                endTime: calendar.date(byAdding: .day, value: -1, to: today)!.addingTimeInterval(11.33 * 3600)
            ),
            Trip(
                id: "trip-091", vehicleId: "0254c00e-1aa5-430c-8069-4e0df7acaf9a", driverId: "drv-8821",
                startName: "Pune Distribution Center", endName: "Mumbai Warehouse",
                distanceKm: 150, actualDurationMin: 225,
                status: "completed",
                startTime: calendar.date(byAdding: .day, value: -2, to: today)!.addingTimeInterval(9 * 3600),
                endTime: calendar.date(byAdding: .day, value: -2, to: today)!.addingTimeInterval(12.75 * 3600)
            ),
            Trip(
                id: "trip-088", vehicleId: "0254c00e-1aa5-430c-8069-4e0df7acaf9a", driverId: "drv-8821",
                startName: "Mumbai Warehouse", endName: "Nashik Hub",
                distanceKm: 167, actualDurationMin: 250,
                status: "completed",
                startTime: calendar.date(byAdding: .day, value: -3, to: today)!.addingTimeInterval(7 * 3600),
                endTime: calendar.date(byAdding: .day, value: -3, to: today)!.addingTimeInterval(11.17 * 3600)
            ),
            Trip(
                id: "trip-085", vehicleId: "0254c00e-1aa5-430c-8069-4e0df7acaf9a", driverId: "drv-8821",
                startName: "Nashik Hub", endName: "Mumbai Warehouse",
                distanceKm: 170, actualDurationMin: 270,
                status: "completed",
                startTime: calendar.date(byAdding: .day, value: -4, to: today)!.addingTimeInterval(8 * 3600),
                endTime: calendar.date(byAdding: .day, value: -4, to: today)!.addingTimeInterval(12.5 * 3600)
            ),
            Trip(
                id: "trip-080", vehicleId: "0254c00e-1aa5-430c-8069-4e0df7acaf9a", driverId: "drv-8821",
                startName: "Mumbai Warehouse", endName: "Surat Terminal",
                distanceKm: 284, actualDurationMin: 375,
                status: "completed",
                startTime: calendar.date(byAdding: .day, value: -7, to: today)!.addingTimeInterval(6 * 3600),
                endTime: calendar.date(byAdding: .day, value: -7, to: today)!.addingTimeInterval(12.25 * 3600)
            ),
        ]
    }

    public func fetchTodayStats() -> DriverDayStats {
        DriverDayStats(
            tripsCompleted: 2,
            totalDistanceKm: 298,
            drivingTimeMinutes: 425
        )
    }
}
