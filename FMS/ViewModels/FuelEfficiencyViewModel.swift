import Foundation
import Observation
import Supabase

/// ViewModel for User Story 2: Vehicle Fuel Efficiency.
@Observable
public final class FuelEfficiencyViewModel {

  // MARK: - State
  public var vehicles: [VehicleFuelEfficiency] = []
  public var isLoading = false
  public var errorMessage: String? = nil
  public var sortBestFirst = true

  // MARK: - Computed

  public var sortedVehicles: [VehicleFuelEfficiency] {
    vehicles.sorted {
      sortBestFirst
        ? $0.kmPerLiter > $1.kmPerLiter
        : $0.kmPerLiter < $1.kmPerLiter
    }
  }

  // MARK: - Fetch

  @MainActor
  public func fetchEfficiency() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let fetched: [VehicleFuelEfficiency] = try await SupabaseService.shared.client
        .from("vehicle_fuel_efficiency")
        .select()
        .execute()
        .value
      self.vehicles = fetched
      #if DEBUG
        if let first = fetched.first {
          print(
            "Fuel efficiency reports fetched: \(fetched.count). First row -> plate: \(first.plateNumber), km/L: \(first.kmPerLiter)"
          )
        } else {
          print("Fuel efficiency reports fetched: 0 rows")
        }
      #endif
    } catch {
      self.errorMessage = error.localizedDescription
      print("Error fetching fuel efficiency: \(error)")
    }
  }
}
