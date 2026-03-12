import Foundation
import Observation

// MARK: - Shift Timeline Entry

/// A single event in the shift timeline view.
public struct ShiftTimelineEntry: Identifiable {
    public var id: String
    public var time: Date
    public var label: String
    public var type: EntryType

    public enum EntryType {
        case shiftStart
        case breakStart
        case resume
        case shiftEnd
    }

    public var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: time)
    }
}

// MARK: - ShiftViewModel

/// ViewModel for the Driver Shift Detail Screen.
///
/// Assembles a shift timeline from `DriverVehicleAssignment` + `BreakLog`,
/// computes progress, and provides all data for `DriverShiftDetailView`.
@Observable
public final class ShiftViewModel {

    // MARK: - Data
    public var driverName: String
    public var vehicleDisplayName: String?
    public var plateNumber: String?
    public var shiftStart: Date?
    public var shiftEnd: Date?
    public var breakLogs: [BreakLog] = []
    public var timelineEntries: [ShiftTimelineEntry] = []

    // MARK: - Computed

    public var totalShiftHours: Double {
        guard let s = shiftStart, let e = shiftEnd else { return 8 }
        return max(0, e.timeIntervalSince(s) / 3600)
    }

    public var elapsedHours: Double {
        guard let s = shiftStart else { return 0 }
        let elapsed = Date().timeIntervalSince(s) / 3600
        return min(max(0, elapsed), totalShiftHours)
    }

    public var progress: Double {
        guard totalShiftHours > 0 else { return 0 }
        return elapsedHours / totalShiftHours
    }

    public var progressLabel: String {
        let wH = Int(elapsedHours)
        let wM = Int((elapsedHours - Double(wH)) * 60)
        let tH = Int(totalShiftHours)
        return "\(wH)h \(wM)m / \(tH)h"
    }

    // MARK: - Init

    public init(shift: ShiftDisplayItem) {
        self.driverName = shift.driverName
        self.plateNumber = shift.plateNumber
        if let m = shift.vehicleManufacturer, let mdl = shift.vehicleModel {
            self.vehicleDisplayName = "\(m) \(mdl)"
        }
        self.shiftStart = shift.shiftStart
        self.shiftEnd = shift.shiftEnd

        // Build mock break logs
        let now = Date()
        self.breakLogs = [
            BreakLog(id: "brk-s1", driverId: shift.driverId,
                     startTime: now.addingTimeInterval(-2.5 * 3600),
                     endTime: now.addingTimeInterval(-2.25 * 3600),
                     durationMinutes: 15)
        ]

        // Build timeline
        self.timelineEntries = buildTimeline()
    }

    // MARK: - Timeline Builder

    private func buildTimeline() -> [ShiftTimelineEntry] {
        var entries: [ShiftTimelineEntry] = []

        if let start = shiftStart {
            entries.append(ShiftTimelineEntry(
                id: "tl-start", time: start,
                label: "Shift Start", type: .shiftStart
            ))
        }

        for (i, brk) in breakLogs.enumerated() {
            if let brkStart = brk.startTime {
                entries.append(ShiftTimelineEntry(
                    id: "tl-brk-\(i)", time: brkStart,
                    label: "Break", type: .breakStart
                ))
            }
            if let brkEnd = brk.endTime {
                entries.append(ShiftTimelineEntry(
                    id: "tl-res-\(i)", time: brkEnd,
                    label: "Resume", type: .resume
                ))
            }
        }

        if let end = shiftEnd {
            entries.append(ShiftTimelineEntry(
                id: "tl-end", time: end,
                label: "Shift End", type: .shiftEnd
            ))
        }

        return entries.sorted { $0.time < $1.time }
    }
}
