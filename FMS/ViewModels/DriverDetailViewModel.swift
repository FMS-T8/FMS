import Foundation
import Observation
import Supabase

// MARK: - DriverDetailViewModel

/// ViewModel for the Driver Detail Screen.
///
/// Loads all detail data for a single driver using existing data models:
/// `Driver`, `Vehicle`, `DriverVehicleAssignment`, `Trip`, `BreakLog`, `Incident`.
///
/// **Integration**: Replace mock data in `init` with real service/repository calls.
@Observable
public final class DriverDetailViewModel {

  // MARK: - Identity
  public var driverId: String

  // MARK: - Data
  public var driverName: String
  public var employeeID: String
  public var phone: String?
  public var availabilityStatus: DriverAvailabilityStatus

  // MARK: - Edit State
  public var email: String? = nil

  // MARK: - Deletion State
  public var isDeleting: Bool = false
  public var deleteError: String? = nil
  public var deleteSuccess: Bool = false

  /// Assigned vehicle (from Vehicle model).
  public var vehicle: Vehicle?

  /// Active shift assignment (from DriverVehicleAssignment model).
  public var assignment: DriverVehicleAssignment?

  /// Current trip, nil if no active trip (from Trip model).
  public var currentTrip: Trip?

  /// Recent break history (from BreakLog model).
  public var breakLogs: [BreakLog] = []

  /// Driving incidents (from Incident model).
  public var incidents: [Incident] = []

  // MARK: - Computed: Shift Progress

  /// Total shift hours.
  public var totalShiftHours: Double {
    guard let s = assignment?.shiftStart, let e = assignment?.shiftEnd else { return 8 }
    return max(0, e.timeIntervalSince(s) / 3600)
  }

  /// Hours worked so far.
  public var hoursWorked: Double {
    guard let s = assignment?.shiftStart else { return 0 }
    let elapsed = Date().timeIntervalSince(s) / 3600
    return min(max(0, elapsed), totalShiftHours)
  }

  /// Shift progress ratio 0.0–1.0.
  public var shiftProgress: Double {
    guard totalShiftHours > 0 else { return 0 }
    return hoursWorked / totalShiftHours
  }

  /// Formatted label, e.g. "6h 20m / 8h".
  public var shiftProgressLabel: String {
    let wH = Int(hoursWorked)
    let wM = Int((hoursWorked - Double(wH)) * 60)
    let tH = Int(totalShiftHours)
    return "\(wH)h \(wM)m / \(tH)h"
  }

  /// Formatted shift start time.
  public var shiftStartLabel: String {
    guard let d = assignment?.shiftStart else { return "--" }
    return Self.timeFormatter.string(from: d)
  }

  /// Formatted shift end time.
  public var shiftEndLabel: String {
    guard let d = assignment?.shiftEnd else { return "--" }
    return Self.timeFormatter.string(from: d)
  }

  /// Trip display string, e.g. "Mysuru → Bengaluru".
  public var tripRouteLabel: String? {
    guard let trip = currentTrip,
      let start = trip.startName,
      let end = trip.endName
    else { return nil }
    return "\(start) → \(end)"
  }

  /// Trip distance label including units.
  public var tripDistanceLabel: String? {
    guard let km = currentTrip?.distanceKm else { return nil }
    return "\(Int(km)) km"
  }

  /// Trip status display.
  public var tripStatusLabel: String {
    currentTrip?.status?.capitalized ?? "No active trip"
  }

  // MARK: - Edit

  /// Updates the locally-displayed driver fields after a successful edit.
  public func applyEdit(name: String, phone: String?) {
    self.driverName = name
    self.phone = phone
  }

  // MARK: - Computed: Active Trip Guard

  /// True if the driver is currently on an active or in-transit trip.
  public var hasActiveTrip: Bool {
    guard let trip = currentTrip else { return false }
    return trip.status == "in_transit" || trip.status == "active"
  }

  // MARK: - Delete

  /// Soft-deletes the driver by setting is_deleted = true on the users table.
  ///
  /// Performs a server-side active-trip check before deleting to prevent race
  /// conditions where the local `currentTrip` snapshot may be stale.
  @MainActor
  public func deleteDriver() async {
    // Fast-path: client-side guard (avoids a network round-trip in the common case).
    guard !hasActiveTrip else {
      deleteError = "Driver cannot be deleted while assigned to active trips."
      return
    }
    isDeleting = true
    do {
      // Server-side authoritative check — catches races where a trip was
      // assigned after this screen loaded.
      struct ActiveTripRow: Decodable { let id: String }
      let activeTrips: [ActiveTripRow] = try await SupabaseService.shared.client
        .from("trips")
        .select("id")
        .eq("driver_id", value: driverId)
        .in("status", values: ["active", "in_transit"])
        .execute()
        .value

      guard activeTrips.isEmpty else {
        deleteError = "Driver cannot be deleted while assigned to active trips."
        isDeleting = false
        return
      }

      struct UpdatePayload: Encodable {
        let is_deleted: Bool
      }
      try await SupabaseService.shared.client
        .from("users")
        .update(UpdatePayload(is_deleted: true))
        .eq("id", value: driverId)
        .eq("is_deleted", value: false)
        .execute()
      deleteSuccess = true
    } catch {
      deleteError = error.localizedDescription
    }
    isDeleting = false
  }

  // MARK: - Init

  /// Production initializer accepting real related models from caller/service.
  public init(
    driver: DriverDisplayItem,
    vehicle: Vehicle? = nil,
    assignment: DriverVehicleAssignment? = nil,
    currentTrip: Trip? = nil,
    breakLogs: [BreakLog] = [],
    incidents: [Incident] = []
  ) {
    self.driverId = driver.id
    self.driverName = driver.name
    self.employeeID = driver.employeeID
    self.phone = driver.phone
    self.email = nil
    self.availabilityStatus = driver.availabilityStatus
    self.vehicle = vehicle
    self.assignment = assignment
    self.currentTrip = currentTrip
    self.breakLogs = breakLogs
    self.incidents = incidents
  }

  /// Mock factory for development/preview with synthesized data.
  public static func mock(from driver: DriverDisplayItem) -> DriverDetailViewModel {
    let now = Date()

    // Mock vehicle
    let vehicle: Vehicle? = {
      guard let vMfr = driver.vehicleManufacturer, let vMdl = driver.vehicleModel else {
        return nil
      }
      return Vehicle(
        id: driver.vehicleId ?? UUID().uuidString,
        plateNumber: driver.plateNumber ?? "N/A",
        chassisNumber: "CHS-\(driver.id.suffix(4))",
        manufacturer: vMfr,
        model: vMdl
      )
    }()

    // Mock assignment
    let assignment: DriverVehicleAssignment? = {
      guard let ss = driver.shiftStart, let se = driver.shiftEnd else { return nil }
      return DriverVehicleAssignment(
        id: "asgn-\(driver.id)",
        driverId: driver.id,
        vehicleId: driver.vehicleId,
        shiftStart: ss,
        shiftEnd: se,
        status: driver.availabilityStatus.rawValue
      )
    }()

    // Mock trip
    let trip: Trip? = {
      guard driver.activeTripId != nil else { return nil }
      return Trip(
        id: driver.activeTripId!,
        vehicleId: driver.vehicleId,
        driverId: driver.id,
        startName: "Mysuru",
        endName: "Bengaluru",
        distanceKm: 150,
        status: "in_transit",
        startTime: driver.shiftStart
      )
    }()

    // Mock break logs
    let breaks = [
      BreakLog(
        id: "brk-1", driverId: driver.id,
        startTime: now.addingTimeInterval(-2 * 3600),
        endTime: now.addingTimeInterval(-1.75 * 3600),
        durationMinutes: 15),
      BreakLog(
        id: "brk-2", driverId: driver.id,
        startTime: now.addingTimeInterval(-5 * 3600),
        endTime: now.addingTimeInterval(-4.5 * 3600),
        durationMinutes: 30),
    ]

    // Mock incidents
    let incidents = [
      Incident(
        id: "inc-1", driverId: driver.id,
        severity: "Harsh Braking",
        createdAt: now.addingTimeInterval(-1.5 * 3600)),
      Incident(
        id: "inc-2", driverId: driver.id,
        severity: "Rapid Acceleration",
        createdAt: now.addingTimeInterval(-3 * 3600)),
    ]

    return DriverDetailViewModel(
      driver: driver,
      vehicle: vehicle,
      assignment: assignment,
      currentTrip: trip,
      breakLogs: breaks,
      incidents: incidents
    )
  }

  // MARK: - Helpers

  private static let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "hh:mm a"
    return f
  }()

  /// Format a date as time string.
  public func formatTime(_ date: Date?) -> String {
    guard let d = date else { return "--" }
    return Self.timeFormatter.string(from: d)
  }
}
