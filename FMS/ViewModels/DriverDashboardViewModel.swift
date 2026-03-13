import Foundation
import Observation

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

    public func submitIssueReport(_ report: IssueReport) {
        issueReports.append(report)
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
    public init() {}

    public func fetchCurrentDriver() -> DriverDisplayItem {
        let now = Date()
        return DriverDisplayItem(
            id: "drv-8821", name: "Alex Thompson", employeeID: "#DRV-8821",
            phone: "+91 98765 43210",
            vehicleId: "v-001", vehicleManufacturer: "Freightliner", vehicleModel: "M2",
            plateNumber: "FLD-829",
            availabilityStatus: .onTrip,
            shiftStart: now.addingTimeInterval(-3 * 3600),
            shiftEnd: now.addingTimeInterval(5 * 3600),
            activeTripId: "trip-101"
        )
    }

    public func fetchAssignedVehicle() -> Vehicle? {
        Vehicle(
            id: "v-001",
            plateNumber: "FLD-829",
            chassisNumber: "1FVACYDC0LHKG3847",
            manufacturer: "Freightliner",
            model: "M2",
            fuelType: "Diesel",
            fuelTankCapacity: 300,
            odometer: 45_230,
            status: "active"
        )
    }

    public func fetchActiveTrip() -> Trip? {
        Trip(
            id: "trip-101",
            vehicleId: "v-001",
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

        return [
            Trip(
                id: "trip-102", vehicleId: "v-001", driverId: "drv-8821",
                shipmentDescription: "Textile shipment",
                startName: "Mumbai Warehouse", endName: "Nashik Hub",
                distanceKm: 167, estimatedDurationMin: 250,
                status: "scheduled",
                startTime: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: tomorrow)
            ),
            Trip(
                id: "trip-103", vehicleId: "v-001", driverId: "drv-8821",
                shipmentDescription: "FMCG delivery",
                startName: "Mumbai Warehouse", endName: "Kolhapur Depot",
                distanceKm: 230, estimatedDurationMin: 330,
                status: "scheduled",
                startTime: calendar.date(bySettingHour: 7, minute: 30, second: 0, of: dayAfter)
            ),
            Trip(
                id: "trip-104", vehicleId: "v-001", driverId: "drv-8821",
                shipmentDescription: "Auto parts",
                startName: "Mumbai Warehouse", endName: "Aurangabad Center",
                distanceKm: 335, estimatedDurationMin: 420,
                status: "scheduled",
                startTime: calendar.date(bySettingHour: 6, minute: 0, second: 0, of: threeDays)
            ),
        ]
    }

    public func fetchCompletedTrips() -> [Trip] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return [
            Trip(
                id: "trip-095", vehicleId: "v-001", driverId: "drv-8821",
                startName: "Mumbai Warehouse", endName: "Pune Distribution Center",
                distanceKm: 148, actualDurationMin: 200,
                status: "completed",
                startTime: calendar.date(byAdding: .day, value: -1, to: today)!.addingTimeInterval(8 * 3600),
                endTime: calendar.date(byAdding: .day, value: -1, to: today)!.addingTimeInterval(11.33 * 3600)
            ),
            Trip(
                id: "trip-091", vehicleId: "v-001", driverId: "drv-8821",
                startName: "Pune Distribution Center", endName: "Mumbai Warehouse",
                distanceKm: 150, actualDurationMin: 225,
                status: "completed",
                startTime: calendar.date(byAdding: .day, value: -2, to: today)!.addingTimeInterval(9 * 3600),
                endTime: calendar.date(byAdding: .day, value: -2, to: today)!.addingTimeInterval(12.75 * 3600)
            ),
            Trip(
                id: "trip-088", vehicleId: "v-001", driverId: "drv-8821",
                startName: "Mumbai Warehouse", endName: "Nashik Hub",
                distanceKm: 167, actualDurationMin: 250,
                status: "completed",
                startTime: calendar.date(byAdding: .day, value: -3, to: today)!.addingTimeInterval(7 * 3600),
                endTime: calendar.date(byAdding: .day, value: -3, to: today)!.addingTimeInterval(11.17 * 3600)
            ),
            Trip(
                id: "trip-085", vehicleId: "v-001", driverId: "drv-8821",
                startName: "Nashik Hub", endName: "Mumbai Warehouse",
                distanceKm: 170, actualDurationMin: 270,
                status: "completed",
                startTime: calendar.date(byAdding: .day, value: -4, to: today)!.addingTimeInterval(8 * 3600),
                endTime: calendar.date(byAdding: .day, value: -4, to: today)!.addingTimeInterval(12.5 * 3600)
            ),
            Trip(
                id: "trip-080", vehicleId: "v-001", driverId: "drv-8821",
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
