import Foundation
import Observation
import Supabase
import PostgREST

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

  // MARK: - Data (from Supabase)
  public var availableDrivers: [(id: String, name: String)] = []
  public var availableVehicles: [(id: String, display: String)] = []

  // MARK: - Loading State
  public var isLoading: Bool = false
  public var isFetchingData: Bool = false
  public var fetchErrorMessage: String? = nil
  
  private var supabaseDecoder: JSONDecoder {
      let decoder = JSONDecoder()
      let dateFormatter = DateFormatter()
      dateFormatter.locale = Locale(identifier: "en_US_POSIX")
      
      decoder.dateDecodingStrategy = .custom { decoder in
          let container = try decoder.singleValueContainer()
          let dateStr = try container.decode(String.self)
          
          dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
          if let date = dateFormatter.date(from: dateStr) { return date }
          
          dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
          if let date = dateFormatter.date(from: dateStr) { return date }
          
          dateFormatter.dateFormat = "yyyy-MM-dd"
          if let date = dateFormatter.date(from: dateStr) { return date }
          
          throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(dateStr)")
      }
      return decoder
  }

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
  
  public func fetchData() async {
      isFetchingData = true
      defer { isFetchingData = false }
      
      do {
          fetchErrorMessage = nil
          async let driversResponse = try SupabaseService.shared.client
              .from("users")
              .select()
              .eq("role", value: "driver")
              .eq("is_deleted", value: false)
              .execute()
              
          async let vehiclesResponse = try SupabaseService.shared.client
              .from("vehicles")
              .select()
              .execute()
              
          let (dRes, vRes) = try await (driversResponse, vehiclesResponse)
          
          let drivers = try supabaseDecoder.decode([User].self, from: dRes.data)
          let vehicles = try supabaseDecoder.decode([Vehicle].self, from: vRes.data)
          
          self.availableDrivers = drivers.map { (id: $0.id, name: $0.name) }
          self.availableVehicles = vehicles.map {
              let make = $0.manufacturer ?? "Unknown"
              let model = $0.model ?? "Vehicle"
              let plate = $0.plateNumber
              return (id: $0.id, display: "\(make) \(model) · \(plate)")
          }
      } catch {
          print("Error fetching shift assignment data: \(error)")
          fetchErrorMessage = "Unable to load drivers and vehicles. Please try again later."
      }
  }

  /// Assigns the shift asynchronously.
  /// - Throws: An error if the assignment fails.
  public func assignShift() async throws {
      struct ShiftInsert: Encodable {
          var driver_id: String
          var vehicle_id: String
          var shift_start: Date
          var shift_end: Date
          var status: String
      }
      
      // Combine date and time
      let calendar = Calendar.current
      let startComponents = calendar.dateComponents([.hour, .minute], from: shiftStartTime)
      let endComponents = calendar.dateComponents([.hour, .minute], from: shiftEndTime)
      
      enum ShiftAssignmentError: LocalizedError {
          case invalidTimeComponents
          case invalidDateConstruction
      }

      guard let startHour = startComponents.hour, let startMinute = startComponents.minute,
            let endHour = endComponents.hour, let endMinute = endComponents.minute else {
          throw ShiftAssignmentError.invalidTimeComponents
      }
      
      guard
        let start = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: shiftDate),
        let rawEnd = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: shiftDate)
      else {
        throw ShiftAssignmentError.invalidDateConstruction
      }
      
      let end = normalizedEndDate(for: start, end: rawEnd)
      
      let insert = ShiftInsert(
          driver_id: selectedDriverId,
          vehicle_id: selectedVehicleId,
          shift_start: start,
          shift_end: end,
          status: "scheduled"
      )
      
      let client = SupabaseService.shared.client
      try await client
          .from("driver_vehicle_assignments")
          .insert(insert)
          .execute()
  }
}
