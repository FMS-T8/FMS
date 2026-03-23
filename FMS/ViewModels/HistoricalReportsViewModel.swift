import Foundation
import Observation
import Supabase

/// ViewModel for User Story 3: Historical Reports.
@Observable
public final class HistoricalReportsViewModel {

  // MARK: - State
  public var reports: [HistoricalTripReport] = []
  public var isLoading = false
  public var errorMessage: String? = nil
  public var startDate: Date =
    Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
  public var endDate: Date = Date()

  // MARK: - Fetch

  @MainActor
  public func fetchReports() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    let formatter = ISO8601DateFormatter()

    do {
      let fetched: [HistoricalTripReport] = try await SupabaseService.shared.client
        .from("trips")
        .select(
          "id, start_time, distance_km, fuel_used_liters, vehicles(plate_number), users:driver_id(name)"
        )
        .gte("start_time", value: formatter.string(from: startDate))
        .lte("start_time", value: formatter.string(from: endDate))
        .order("start_time", ascending: false)
        .execute()
        .value
      self.reports = fetched
      #if DEBUG
        if let first = fetched.first {
          print(
            "Historical reports fetched: \(fetched.count). First row -> id: \(first.id), plate: \(first.plateNumber)"
          )
        } else {
          print("Historical reports fetched: 0 rows")
        }
      #endif
    } catch {
      self.errorMessage = error.localizedDescription
      print("Error fetching historical reports: \(error)")
    }
  }

  // MARK: - CSV Export

  /// Generates a CSV string from the currently loaded reports.
  public func generateCSV() -> String {
    var csv = "Date,Vehicle,Driver,Distance (km),Fuel (L)\n"
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium

    for report in reports {
      let dateStr: String
      if let d = report.startTime {
        dateStr = dateFormatter.string(from: d)
      } else {
        dateStr = "—"
      }
      let distance = report.distanceKm.map { String(format: "%.1f", $0) } ?? "—"
      let fuel = report.fuelUsedLiters.map { String(format: "%.1f", $0) } ?? "—"
      let escapedDate = escapeCSVField(dateStr)
      let escapedPlate = escapeCSVField(report.plateNumber)
      let escapedDriver = escapeCSVField(report.driverName)
      let escapedDistance = escapeCSVField(distance)
      let escapedFuel = escapeCSVField(fuel)
      csv += "\(escapedDate),\(escapedPlate),\(escapedDriver),\(escapedDistance),\(escapedFuel)\n"
    }
    return csv
  }

  private func escapeCSVField(_ value: String) -> String {
    let containsSpecialCharacters =
      value.contains(",") || value.contains("\"") || value.contains("\n")
    guard containsSpecialCharacters else { return value }
    let escapedQuotes = value.replacingOccurrences(of: "\"", with: "\"\"")
    return "\"\(escapedQuotes)\""
  }
}
