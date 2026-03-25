import Foundation
import Observation
import Supabase

/// ViewModel for User Story 2: Vehicle Fuel Efficiency.
@Observable
public final class FuelEfficiencyViewModel {

  private struct TripEfficiencySample: Decodable {
    let vehicleId: String?
    let distanceKm: Double?
    let fuelUsedLiters: Double?
    let startTime: Date?

    enum CodingKeys: String, CodingKey {
      case vehicleId = "vehicle_id"
      case distanceKm = "distance_km"
      case fuelUsedLiters = "fuel_used_liters"
      case startTime = "start_time"
    }
  }

  private struct VehicleIdRow: Decodable {
    let id: String
  }

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
      let visibleVehicleIds = try await fetchVisibleVehicleIds()
      guard !visibleVehicleIds.isEmpty else {
        self.vehicles = []
        return
      }

      let fetched: [VehicleFuelEfficiency] = try await SupabaseService.shared.client
        .from("vehicle_fuel_efficiency")
        .select()
        .in("vehicle_id", values: visibleVehicleIds)
        .execute()
        .value
      self.vehicles = try await enrichWithDerivedBaselineIfNeeded(fetched)
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

  private func enrichWithDerivedBaselineIfNeeded(_ list: [VehicleFuelEfficiency]) async throws
    -> [VehicleFuelEfficiency]
  {
    let idsNeedingBaseline =
      list
      .filter { $0.baselineKmPerLiter == $0.kmPerLiter }
      .map(\.vehicleId)
    guard !idsNeedingBaseline.isEmpty else { return list }

    let now = Date()
    guard
      let windowStart = Calendar.current.date(byAdding: .day, value: -60, to: now),
      let currentStart = Calendar.current.date(byAdding: .day, value: -30, to: now)
    else {
      return list
    }

    let iso = ISO8601DateFormatter()
    let rows: [TripEfficiencySample] = try await SupabaseService.shared.client
      .from("trips")
      .select("vehicle_id, distance_km, fuel_used_liters, start_time")
      .in("vehicle_id", values: idsNeedingBaseline)
      .gte("start_time", value: iso.string(from: windowStart))
      .lte("start_time", value: iso.string(from: now))
      .execute()
      .value

    typealias Acc = (distance: Double, fuel: Double)
    var previous: [String: Acc] = [:]

    for row in rows {
      guard
        let vehicleId = row.vehicleId,
        let distance = row.distanceKm,
        let fuel = row.fuelUsedLiters,
        fuel > 0,
        let tripDate = row.startTime
      else {
        continue
      }

      if tripDate < currentStart {
        let existing = previous[vehicleId] ?? (0, 0)
        previous[vehicleId] = (existing.distance + distance, existing.fuel + fuel)
      }
    }

    return list.map { vehicle in
      guard idsNeedingBaseline.contains(vehicle.vehicleId) else { return vehicle }
      guard let acc = previous[vehicle.vehicleId], acc.fuel > 0 else { return vehicle }
      let baseline = acc.distance / acc.fuel
      return VehicleFuelEfficiency(
        vehicleId: vehicle.vehicleId,
        plateNumber: vehicle.plateNumber,
        totalTrips: vehicle.totalTrips,
        kmPerLiter: vehicle.kmPerLiter,
        baselineKmPerLiter: baseline
      )
    }
  }

  private func fetchVisibleVehicleIds() async throws -> [String] {
    let rows: [VehicleIdRow] = try await SupabaseService.shared.client
      .from("vehicles")
      .select("id")
      .execute()
      .value
    return rows.map(\.id)
  }
}
