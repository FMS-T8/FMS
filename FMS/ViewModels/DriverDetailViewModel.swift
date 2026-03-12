import Foundation
import Observation

// MARK: - DriverDetailViewModel

/// ViewModel for the Driver Detail Screen.
///
/// Loads all detail data for a single driver using existing data models:
/// `Driver`, `Vehicle`, `DriverVehicleAssignment`, `Trip`, `BreakLog`, `Incident`.
///
/// **Integration**: Replace mock data in `init` with real service/repository calls.
@Observable
public final class DriverDetailViewModel {

    // MARK: - Data
    public var driverName: String
    public var employeeID: String
    public var phone: String?
    public var availabilityStatus: DriverAvailabilityStatus

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
              let end = trip.endName else { return nil }
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

    // MARK: - Init

    /// Creates the VM for a given driver display item.
    /// In production, this would fetch from a service.
    public init(driver: DriverDisplayItem) {
        self.driverName = driver.name
        self.employeeID = driver.employeeID
        self.phone = driver.phone
        self.availabilityStatus = driver.availabilityStatus

        // Mock vehicle
        if let vMfr = driver.vehicleManufacturer, let vMdl = driver.vehicleModel {
            self.vehicle = Vehicle(
                id: driver.vehicleId ?? UUID().uuidString,
                plateNumber: driver.plateNumber ?? "N/A",
                chassisNumber: "CHS-\(driver.id.suffix(4))",
                manufacturer: vMfr,
                model: vMdl,
                fuelType: "Diesel",
                fuelTankCapacity: 300,
                createdAt: Date()
            )
        }

        // Mock assignment
        if let ss = driver.shiftStart, let se = driver.shiftEnd {
            self.assignment = DriverVehicleAssignment(
                id: "asgn-\(driver.id)",
                driverId: driver.id,
                vehicleId: driver.vehicleId,
                shiftStart: ss,
                shiftEnd: se,
                status: driver.availabilityStatus.rawValue
            )
        }

        // Mock trip
        if driver.activeTripId != nil {
            self.currentTrip = Trip(
                id: driver.activeTripId!,
                vehicleId: driver.vehicleId,
                driverId: driver.id,
                startName: "Mysuru",
                endName: "Bengaluru",
                distanceKm: 150,
                status: "in_transit",
                startTime: driver.shiftStart
            )
        }

        // Mock break logs
        let now = Date()
        self.breakLogs = [
            BreakLog(id: "brk-1", driverId: driver.id,
                     startTime: now.addingTimeInterval(-2 * 3600),
                     endTime: now.addingTimeInterval(-1.75 * 3600),
                     durationMinutes: 15),
            BreakLog(id: "brk-2", driverId: driver.id,
                     startTime: now.addingTimeInterval(-5 * 3600),
                     endTime: now.addingTimeInterval(-4.5 * 3600),
                     durationMinutes: 30)
        ]

        // Mock incidents
        self.incidents = [
            Incident(id: "inc-1", driverId: driver.id,
                     severity: "Harsh Braking",
                     createdAt: now.addingTimeInterval(-1.5 * 3600)),
            Incident(id: "inc-2", driverId: driver.id,
                     severity: "Rapid Acceleration",
                     createdAt: now.addingTimeInterval(-3 * 3600))
        ]
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
