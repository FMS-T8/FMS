import Foundation
import Observation
import Supabase

// MARK: - Drivers Tab Selection

/// Identifies which sub-tab is active in the Drivers screen.
public enum DriversTab: String, CaseIterable {
  case directory = "Directory"
  case shifts = "Shifts"
}

// MARK: - Shift Display Item

/// Lightweight display wrapper for a shift card, assembled from
/// `DriverVehicleAssignment` + `Driver` + `Vehicle`.
public struct ShiftDisplayItem: Identifiable, Hashable {
  public var id: String
  public var driverId: String
  public var driverName: String
  public var vehicleId: String?
  public var vehicleManufacturer: String?
  public var vehicleModel: String?
  public var plateNumber: String?
  public var shiftStart: Date?
  public var shiftEnd: Date?
  public var status: String  // "on_duty", "break", "not_started"

  /// Human-readable status label.
  public var statusLabel: String {
    switch status {
    case "on_duty": return "On Duty"
    case "break": return "Break"
    case "not_started": return "Not Started"
    default: return status.capitalized
    }
  }

  /// Shift duration in hours.
  public var shiftDurationHours: Double {
    guard let s = shiftStart, let e = shiftEnd else { return 8 }
    return max(0, e.timeIntervalSince(s) / 3600)
  }

  /// Hours elapsed (capped).
  public var elapsedHours: Double {
    guard let s = shiftStart else { return 0 }
    let elapsed = Date().timeIntervalSince(s) / 3600
    return min(max(0, elapsed), shiftDurationHours)
  }

  /// 0.0–1.0 progress.
  public var progress: Double {
    guard shiftDurationHours > 0 else { return 0 }
    return elapsedHours / shiftDurationHours
  }

  /// Formatted label, e.g. "6h 30m / 8h".
  public var progressLabel: String {
    let wH = Int(elapsedHours)
    let wM = Int((elapsedHours - Double(wH)) * 60)
    let tH = Int(shiftDurationHours)
    return "\(wH)h \(wM)m / \(tH)h"
  }

  /// Vehicle display name.
  public var vehicleDisplayName: String? {
    guard let m = vehicleManufacturer, let mdl = vehicleModel else { return nil }
    return "\(m) \(mdl)"
  }

  /// Two-letter initials.
  public var avatarInitials: String {
    driverName.split(separator: " ").prefix(2)
      .compactMap { $0.first.map(String.init) }
      .joined()
  }
}

// MARK: - Drivers Data Source Protocol

/// Protocol for providing driver and shift data to the DriversViewModel.
/// Implement this protocol for real repository/service or mock data sources.
public protocol DriversDataSource {
  func fetchDrivers() -> [DriverDisplayItem]
  func fetchShifts() -> [ShiftDisplayItem]
}

// MARK: - Mock Data Source

/// Mock implementation of DriversDataSource for development and previews.
public final class MockDriversDataSource: DriversDataSource {
  public init() {}

  public func fetchDrivers() -> [DriverDisplayItem] {
    DriversViewModel.makeMockDrivers()
  }

  public func fetchShifts() -> [ShiftDisplayItem] {
    DriversViewModel.makeMockShifts()
  }
}

// MARK: - DriversViewModel

/// Central `@Observable` ViewModel for the Drivers module.
///
/// Holds all list data, search/filter state, and the selected date for shifts.
/// All computation happens here — views only read and bind.
@Observable
public final class DriversViewModel {

  // MARK: - Tab State
  public var selectedTab: DriversTab = .directory

  // MARK: - Directory State
  public var drivers: [DriverDisplayItem] = []
  public var searchText: String = ""
  public var selectedFilter: DriverAvailabilityStatus? = nil

  // MARK: - Shifts State
  public var shiftItems: [ShiftDisplayItem] = []
  public var selectedDate: Date = Date()

  // MARK: - Computed: Directory

  /// Filtered driver list (search + status filter).
  public var filteredDrivers: [DriverDisplayItem] {
    drivers.filter { item in
      let matchesSearch: Bool = {
        guard !searchText.isEmpty else { return true }
        let q = searchText.lowercased()
        return item.name.lowercased().contains(q)
          || item.employeeID.lowercased().contains(q)
      }()
      let matchesFilter: Bool = {
        guard let f = selectedFilter else { return true }
        return item.availabilityStatus == f
      }()
      return matchesSearch && matchesFilter
    }
  }

  /// Count of drivers matching a given status (for filter chip badges).
  public func driverCount(for status: DriverAvailabilityStatus?) -> Int {
    guard let status else { return drivers.count }
    return drivers.filter { $0.availabilityStatus == status }.count
  }

  /// On-duty drivers (for summary card).
  public var onDutyCount: Int { driverCount(for: .available) + driverCount(for: .onTrip) }
  /// On-trip drivers.
  public var onTripCount: Int { driverCount(for: .onTrip) }
  /// Off-duty drivers.
  public var offDutyCount: Int { driverCount(for: .offDuty) }
  /// Total drivers.
  public var totalCount: Int { drivers.count }

  // MARK: - Computed: Shifts

  /// 6-day window for the date strip.
  public var weekDays: [Date] {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    return (-1...4).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
  }

  /// Shift items for the selected date (including overnight shifts that overlap).
  public var shiftsForDate: [ShiftDisplayItem] {
    let cal = Calendar.current
    guard let dayStart = cal.startOfDay(for: selectedDate) as Date?,
      let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)
    else {
      return []
    }

    return
      shiftItems
      .filter { item in
        let start = item.shiftStart ?? .distantPast
        let end = item.shiftEnd ?? .distantFuture
        // Include shift if it overlaps the selected day
        return start < dayEnd && end > dayStart
      }
      .sorted { ($0.shiftStart ?? .distantPast) < ($1.shiftStart ?? .distantPast) }
  }

  // MARK: - Init

  /// Initializer with data source dependency injection.
  /// - Parameter dataSource: Source for drivers and shifts data. Defaults to mock for previews.
  /// Production code should explicitly pass a real repository/service implementation.
  public init(dataSource: DriversDataSource = MockDriversDataSource()) {
    self.drivers = dataSource.fetchDrivers()
    self.shiftItems = dataSource.fetchShifts()
  }

  // MARK: - Backend Sync

  /// Pulls the latest drivers from Supabase and maps them to directory cards.
  /// Falls back to existing in-memory data if the request fails.
  @MainActor
  public func reloadDriversFromBackend() async {
    struct DriverUserRow: Decodable {
      let id: String
      let name: String?
      let phone: String?
      let employeeID: String?

      enum CodingKeys: String, CodingKey {
        case id
        case name
        case phone
        case employeeID = "employee_id"
      }
    }

    do {
      let rows: [DriverUserRow] = try await SupabaseService.shared.client
        .from("users")
        .select("id, name, phone, employee_id")
        .eq("role", value: "driver")
        .order("created_at", ascending: false)
        .execute()
        .value

      self.drivers = rows.map { row in
        let fallbackEmployeeId = "#DRV-\(row.id.prefix(4).uppercased())"

        return DriverDisplayItem(
          id: row.id,
          name: (row.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? row.name!
            : "Unnamed Driver",
          employeeID: (row.employeeID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            == false)
            ? row.employeeID!
            : fallbackEmployeeId,
          phone: row.phone,
          vehicleId: nil,
          vehicleManufacturer: nil,
          vehicleModel: nil,
          plateNumber: nil,
          availabilityStatus: .available,
          shiftStart: nil,
          shiftEnd: nil,
          activeTripId: nil
        )
      }
    } catch {
      print("DriversViewModel.reloadDriversFromBackend error: \(error)")
    }
  }
}

// MARK: - Mock Data (replace with service calls)

extension DriversViewModel {

  public static func makeMockDrivers() -> [DriverDisplayItem] {
    let now = Date()
    return [
      DriverDisplayItem(
        id: "drv-8821", name: "Alex Thompson", employeeID: "#DRV-8821",
        phone: "+91 98765 43210",
        vehicleId: "v-001", vehicleManufacturer: "Freightliner", vehicleModel: "M2",
        plateNumber: "FLD-829",
        availabilityStatus: .available,
        shiftStart: now.addingTimeInterval(-3 * 3600),
        shiftEnd: now.addingTimeInterval(5 * 3600),
        activeTripId: nil
      ),
      DriverDisplayItem(
        id: "drv-9104", name: "Sarah Jenkins", employeeID: "#DRV-9104",
        phone: "+91 98765 43211",
        vehicleId: "v-002", vehicleManufacturer: "Volvo", vehicleModel: "VNL 860",
        plateNumber: "XYZ-9876",
        availabilityStatus: .onTrip,
        shiftStart: now.addingTimeInterval(-6.75 * 3600),
        shiftEnd: now.addingTimeInterval(1.25 * 3600),
        activeTripId: "trip-001"
      ),
      DriverDisplayItem(
        id: "drv-7229", name: "Marcus Rodriguez", employeeID: "#DRV-7229",
        phone: "+91 98765 43212",
        vehicleId: "v-003", vehicleManufacturer: "Kenworth", vehicleModel: "T680",
        plateNumber: "KLC-4421",
        availabilityStatus: .offDuty,
        shiftStart: nil, shiftEnd: nil,
        activeTripId: nil
      ),
      DriverDisplayItem(
        id: "drv-8829", name: "Marcus Thompson", employeeID: "#DRV-8829",
        phone: "+91 98765 43213",
        vehicleId: "v-004", vehicleManufacturer: "Volvo", vehicleModel: "FH16",
        plateNumber: "TN11N3067",
        availabilityStatus: .available,
        shiftStart: now.addingTimeInterval(-1.5 * 3600),
        shiftEnd: now.addingTimeInterval(6.5 * 3600),
        activeTripId: "trip-002"
      ),
    ]
  }

  public static func makeMockShifts() -> [ShiftDisplayItem] {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())

    func todayAt(hour: Int, minute: Int = 0) -> Date {
      cal.date(bySettingHour: hour, minute: minute, second: 0, of: today)!
    }

    return [
      ShiftDisplayItem(
        id: "shift-001", driverId: "drv-8829", driverName: "Marcus Thompson",
        vehicleId: "v-004", vehicleManufacturer: "Volvo", vehicleModel: "FH16",
        plateNumber: "TN11N3067",
        shiftStart: todayAt(hour: 8), shiftEnd: todayAt(hour: 18),
        status: "on_duty"
      ),
      ShiftDisplayItem(
        id: "shift-002", driverId: "drv-9104", driverName: "Sarah Jenkins",
        vehicleId: "v-002", vehicleManufacturer: "Scania", vehicleModel: "R500",
        plateNumber: "XYZ-9876",
        shiftStart: todayAt(hour: 9, minute: 30), shiftEnd: todayAt(hour: 19),
        status: "break"
      ),
      ShiftDisplayItem(
        id: "shift-003", driverId: "drv-7741", driverName: "David Lee",
        vehicleId: "v-005", vehicleManufacturer: "Mercedes", vehicleModel: "Actros",
        plateNumber: "DL-4432",
        shiftStart: todayAt(hour: 14), shiftEnd: todayAt(hour: 22),
        status: "not_started"
      ),
      ShiftDisplayItem(
        id: "shift-004", driverId: "drv-8821", driverName: "Alex Thompson",
        vehicleId: "v-001", vehicleManufacturer: "Freightliner", vehicleModel: "M2",
        plateNumber: "FLD-829",
        shiftStart: todayAt(hour: 7), shiftEnd: todayAt(hour: 15),
        status: "on_duty"
      ),
    ]
  }
}
