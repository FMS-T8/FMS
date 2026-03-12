import Foundation
import Observation

// MARK: - ShiftAssignmentViewModel

/// ViewModel for the shift assignment screen.
/// Manages form state for assigning a shift to a driver.
@Observable
public final class ShiftAssignmentViewModel {

  // MARK: - Form State
  public var selectedDriverId: String = ""
  public var selectedVehicleId: String = ""
  public var shiftDate: Date = Date()
  public var shiftStartTime: Date = Date()
  public var shiftEndTime: Date = Date().addingTimeInterval(8 * 3600)

  // MARK: - Data (mock lists — replace with service calls)
  public var availableDrivers: [(id: String, name: String)] = [
    ("drv-8821", "Alex Thompson"),
    ("drv-9104", "Sarah Jenkins"),
    ("drv-7229", "Marcus Rodriguez"),
    ("drv-8829", "Marcus Thompson"),
  ]

  public var availableVehicles: [(id: String, display: String)] = [
    ("v-001", "Freightliner M2 · FLD-829"),
    ("v-002", "Volvo VNL 860 · XYZ-9876"),
    ("v-003", "Kenworth T680 · KLC-4421"),
    ("v-004", "Volvo FH16 · TN11N3067"),
  ]

  // MARK: - Loading State
  public var isLoading: Bool = false

  // MARK: - Validation

  public var isFormValid: Bool {
    guard !selectedDriverId.isEmpty && !selectedVehicleId.isEmpty else {
      return false
    }
    let normalizedEnd = normalizedEndDate(for: shiftStartTime, end: shiftEndTime)
    return normalizedEnd > shiftStartTime
  }

  /// Normalizes the end date for overnight shifts.
  /// If end time-of-day <= start time-of-day, adds one day to end.
  private func normalizedEndDate(for start: Date, end: Date) -> Date {
    let calendar = Calendar.current
    let startComponents = calendar.dateComponents([.hour, .minute], from: start)
    let endComponents = calendar.dateComponents([.hour, .minute], from: end)

    guard let startHour = startComponents.hour, let startMinute = startComponents.minute,
      let endHour = endComponents.hour, let endMinute = endComponents.minute
    else {
      return end
    }

    let startMinutesFromMidnight = startHour * 60 + startMinute
    let endMinutesFromMidnight = endHour * 60 + endMinute

    // If end time-of-day is before or same as start, it's an overnight shift
    if endMinutesFromMidnight <= startMinutesFromMidnight {
      return calendar.date(byAdding: .day, value: 1, to: end) ?? end
    }

    return end
  }

  // MARK: - Actions

  /// Assigns the shift asynchronously.
  /// - Throws: An error if the assignment fails.
  public func assignShift() async throws {
    // TODO: Submit to service/repository
    // Simulate async operation
    try await Task.sleep(for: .seconds(1))

    // Simulate potential failure (remove in production)
    // if Bool.random() { throw NSError(domain: "ShiftAssignment", code: 1) }
  }
}
