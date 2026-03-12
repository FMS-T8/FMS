import Foundation

// MARK: - Driver Availability Status

/// Represents the live availability state of a driver.
public enum DriverAvailabilityStatus: String, Codable, CaseIterable {
    case available = "available"
    case onTrip    = "on_trip"
    case offDuty   = "off_duty"

    /// Human-readable display label.
    public var displayLabel: String {
        switch self {
        case .available: return "Available"
        case .onTrip:    return "On Trip"
        case .offDuty:   return "Off Duty"
        }
    }
}

// MARK: - Driver Display Item

/// A lightweight display model that wraps the existing data models for the
/// Driver Directory list. The service layer hydrates this from
/// `Driver` + `Vehicle` + `DriverVehicleAssignment` + `Trip`.
///
/// Does **not** duplicate data — each field maps 1-to-1 to an existing model
/// field so the integration layer can populate it directly from API responses.
public struct DriverDisplayItem: Codable, Identifiable, Hashable {

    // MARK: Identity — from Driver
    public var id: String
    public var name: String
    public var employeeID: String
    public var phone: String?

    // MARK: Vehicle — from Vehicle
    public var vehicleId: String?
    public var vehicleManufacturer: String?
    public var vehicleModel: String?
    public var plateNumber: String?

    // MARK: Status — derived from DriverVehicleAssignment + Trip
    public var availabilityStatus: DriverAvailabilityStatus

    // MARK: Shift — from DriverVehicleAssignment
    public var shiftStart: Date?
    public var shiftEnd: Date?

    // MARK: Trip — from Trip
    public var activeTripId: String?

    // MARK: Computed

    /// Total planned shift duration in hours (defaults to 8).
    public var shiftDurationHours: Double {
        guard let start = shiftStart, let end = shiftEnd else { return 8 }
        return max(0, end.timeIntervalSince(start) / 3600)
    }

    /// Hours elapsed since shift start (capped at total).
    public var elapsedHours: Double {
        guard let start = shiftStart else { return 0 }
        let elapsed = Date().timeIntervalSince(start) / 3600
        return min(max(0, elapsed), shiftDurationHours)
    }

    /// Progress ratio 0.0–1.0.
    public var shiftProgress: Double {
        guard shiftDurationHours > 0 else { return 0 }
        return elapsedHours / shiftDurationHours
    }

    /// Formatted shift progress label, e.g. "3h 20m / 8h".
    public var shiftProgressLabel: String {
        let worked = elapsedHours
        let total  = shiftDurationHours
        let wH = Int(worked)
        let wM = Int((worked - Double(wH)) * 60)
        let tH = Int(total)
        return "\(wH)h \(wM)m / \(tH)h"
    }

    /// Two-letter initials for the avatar circle.
    public var avatarInitials: String {
        name.split(separator: " ").prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
    }

    /// Combined vehicle description, e.g. "Volvo FH16".
    public var vehicleDisplayName: String? {
        guard let mfr = vehicleManufacturer, let mdl = vehicleModel else { return nil }
        return "\(mfr) \(mdl)"
    }

    // MARK: Init
    public init(
        id: String = UUID().uuidString,
        name: String,
        employeeID: String,
        phone: String? = nil,
        vehicleId: String? = nil,
        vehicleManufacturer: String? = nil,
        vehicleModel: String? = nil,
        plateNumber: String? = nil,
        availabilityStatus: DriverAvailabilityStatus = .available,
        shiftStart: Date? = nil,
        shiftEnd: Date? = nil,
        activeTripId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.employeeID = employeeID
        self.phone = phone
        self.vehicleId = vehicleId
        self.vehicleManufacturer = vehicleManufacturer
        self.vehicleModel = vehicleModel
        self.plateNumber = plateNumber
        self.availabilityStatus = availabilityStatus
        self.shiftStart = shiftStart
        self.shiftEnd = shiftEnd
        self.activeTripId = activeTripId
    }
}
}
