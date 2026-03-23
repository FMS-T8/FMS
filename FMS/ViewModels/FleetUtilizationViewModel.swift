import Foundation
import Observation
import Supabase

/// ViewModel for User Story 4: Fleet Utilization Report.
@Observable
public final class FleetUtilizationViewModel {

  // MARK: - State
  public var vehicles: [FleetUtilization] = []
  public var isLoading = false
  public var errorMessage: String? = nil
  public var showLowOnly = false

  // MARK: - Computed

  /// Fleet-wide average utilization percentage.
  public var averageUtilization: Double {
    guard !vehicles.isEmpty else { return 0 }
    let total = vehicles.reduce(0.0) { $0 + $1.utilizationPercent }
    return total / Double(vehicles.count)
  }

  /// Filtered list respecting the low-utilization toggle.
  public var filteredVehicles: [FleetUtilization] {
    if showLowOnly {
      return vehicles.filter { $0.utilizationPercent < 40 }
    }
    return vehicles
  }

  // MARK: - Fetch

  @MainActor
  public func fetchUtilization() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let fetched: [FleetUtilization] = try await SupabaseService.shared.client
        .from("fleet_utilization")
        .select()
        .execute()
        .value
      self.vehicles = fetched
      #if DEBUG
        if let first = fetched.first {
          print(
            "Fleet utilization reports fetched: \(fetched.count). First row -> plate: \(first.plateNumber), utilization: \(first.utilizationPercent)%"
          )
        } else {
          print("Fleet utilization reports fetched: 0 rows")
        }
      #endif
    } catch {
      self.errorMessage = error.localizedDescription
      print("Error fetching fleet utilization: \(error)")
    }
  }
}
