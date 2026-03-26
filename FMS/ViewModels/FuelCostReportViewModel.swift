import Foundation
import Observation
import Supabase

@Observable
@MainActor
public final class FuelCostReportViewModel {

  public struct Row: Identifiable {
    public let id: String
    public let plateNumber: String
    public let litersConsumed: Double
    public let costPerLiter: Double
    public let totalSpend: Double
    public let budgetAllocated: Double

    public var variance: Double { totalSpend - budgetAllocated }
  }

  public enum VehicleGroup: String, CaseIterable, Identifiable {
    case all = "All"
    case active = "Active"
    case maintenance = "Maintenance"
    case inactive = "Inactive"

    public var id: String { rawValue }
  }

  private struct VehicleRow: Decodable {
    let id: String
    let plateNumber: String
    let status: String?

    enum CodingKeys: String, CodingKey {
      case id
      case plateNumber = "plate_number"
      case status
    }
  }

  private struct TripFuelRow: Decodable {
    let id: String
    let vehicleId: String?
    let distanceKm: Double?
    let fuelUsedLiters: Double?
    let startTime: Date?

    enum CodingKeys: String, CodingKey {
      case id
      case vehicleId = "vehicle_id"
      case distanceKm = "distance_km"
      case fuelUsedLiters = "fuel_used_liters"
      case startTime = "start_time"
    }
  }

  private struct FuelPriceRow: Decodable {
    let tripId: String?
    let amountPaid: Double?
    let fuelVolume: Double?

    enum CodingKeys: String, CodingKey {
      case tripId = "trip_id"
      case amountPaid = "amount_paid"
      case fuelVolume = "fuel_volume"
    }
  }

  public var rows: [Row] = []
  public var isLoading = false
  public var errorMessage: String?
  private var currentFetchID: Int = 0

  public var startDate: Date
  public var endDate: Date
  public var selectedGroup: VehicleGroup = .all

  public init() {
    let now = Date()
    let monthStart =
      Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now))
      ?? now
    self.startDate = monthStart
    self.endDate = now
  }

  public var filteredRows: [Row] {
    rows.sorted { $0.totalSpend > $1.totalSpend }
  }

  public var totals: Row {
    let liters = filteredRows.reduce(0) { $0 + $1.litersConsumed }
    let spend = filteredRows.reduce(0) { $0 + $1.totalSpend }
    let budget = filteredRows.reduce(0) { $0 + $1.budgetAllocated }
    let costPerLiter = liters > 0 ? spend / liters : 0
    return Row(
      id: "totals",
      plateNumber: "Totals",
      litersConsumed: liters,
      costPerLiter: costPerLiter,
      totalSpend: spend,
      budgetAllocated: budget
    )
  }

  public func fetchReport() async {
    currentFetchID += 1
    let fetchID = currentFetchID

    isLoading = true
    errorMessage = nil
    defer {
      if fetchID == currentFetchID {
        isLoading = false
      }
    }

    do {
      let calendar = Calendar.current
      let iso = ISO8601DateFormatter()
      let reportStart = calendar.startOfDay(for: startDate)
      let reportEndExclusive =
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
      let from = iso.string(from: reportStart)
      let toExclusive = iso.string(from: reportEndExclusive)

      var vehiclesQuery = SupabaseService.shared.client
        .from("vehicles")
        .select("id, plate_number, status")

      if selectedGroup != .all {
        vehiclesQuery = vehiclesQuery.eq("status", value: selectedGroup.rawValue.lowercased())
      }

      let vehicles: [VehicleRow] = try await vehiclesQuery.execute().value

      let vehicleIds = vehicles.map { $0.id }

      let trips: [TripFuelRow] = try await SupabaseService.shared.client
        .from("trips")
        .select("id, vehicle_id, distance_km, fuel_used_liters, start_time")
        .in("vehicle_id", values: vehicleIds)
        .gte("start_time", value: from)
        .lt("start_time", value: toExclusive)
        .execute().value

      let fuelRows: [FuelPriceRow] = try await SupabaseService.shared.client
        .from("fuel_logs")
        .select("trip_id, amount_paid, fuel_volume")
        .gte("logged_at", value: from)
        .lt("logged_at", value: toExclusive)
        .execute().value

      let totalPaid = fuelRows.compactMap(\.amountPaid).reduce(0, +)
      let totalVolume = fuelRows.compactMap(\.fuelVolume).reduce(0, +)
      let globalAvgCostPerLiter = totalVolume > 0 ? totalPaid / totalVolume : 0

      let tripVehicleByTripId: [String: String] = trips.reduce(into: [:]) { partial, trip in
        guard let vehicleId = trip.vehicleId else { return }
        partial[trip.id] = vehicleId
      }

      typealias FuelAgg = (paid: Double, volume: Double)
      var fuelAggByVehicle: [String: FuelAgg] = [:]
      for row in fuelRows {
        guard
          let tripId = row.tripId,
          let vehicleId = tripVehicleByTripId[tripId]
        else {
          continue
        }

        var current = fuelAggByVehicle[vehicleId] ?? (0, 0)
        current.paid += row.amountPaid ?? 0
        current.volume += row.fuelVolume ?? 0
        fuelAggByVehicle[vehicleId] = current
      }

      let avgCostPerLiterByVehicle = fuelAggByVehicle.mapValues { aggregate in
        aggregate.volume > 0 ? aggregate.paid / aggregate.volume : globalAvgCostPerLiter
      }

      let manualFuelByRecentTripId = Self.buildManualFuelByTrip(from: fuelRows)

      var litersByVehicle: [String: Double] = [:]
      for row in trips {
        guard let vehicleId = row.vehicleId else { continue }
        let reconciledLiters = Self.reconcileFuelUsage(
          trip: row,
          manualFuelLiters: manualFuelByRecentTripId[row.id]
        )
        litersByVehicle[vehicleId, default: 0] += reconciledLiters
      }

      // Budget approximation based on 90-day historical spend trend.
      let baselineStart = calendar.date(byAdding: .day, value: -90, to: reportStart) ?? reportStart
      let baselineEndExclusive = reportStart
      let historicalFrom = iso.string(from: baselineStart)
      let historicalToExclusive = iso.string(from: baselineEndExclusive)
      let historicalTrips: [TripFuelRow] = try await SupabaseService.shared.client
        .from("trips")
        .select("id, vehicle_id, distance_km, fuel_used_liters, start_time")
        .gte("start_time", value: historicalFrom)
        .lt("start_time", value: historicalToExclusive)
        .execute().value

      let historicalFuelRows: [FuelPriceRow] = try await SupabaseService.shared.client
        .from("fuel_logs")
        .select("trip_id, amount_paid, fuel_volume")
        .gte("logged_at", value: historicalFrom)
        .lt("logged_at", value: historicalToExclusive)
        .execute().value

      let manualFuelByHistoricalTripId = Self.buildManualFuelByTrip(from: historicalFuelRows)

      let baselineDays = max(
        1, calendar.dateComponents([.day], from: baselineStart, to: baselineEndExclusive).day ?? 0)
      let reportDays = max(
        1, calendar.dateComponents([.day], from: reportStart, to: reportEndExclusive).day ?? 0)

      var historicalLitersByVehicle: [String: Double] = [:]
      for row in historicalTrips {
        guard let vehicleId = row.vehicleId else { continue }
        let reconciledLiters = Self.reconcileFuelUsage(
          trip: row,
          manualFuelLiters: manualFuelByHistoricalTripId[row.id]
        )
        historicalLitersByVehicle[vehicleId, default: 0] += reconciledLiters
      }

      // Compute historical average cost per liter from baseline period.
      let historicalTotalPaid = historicalFuelRows.compactMap(\.amountPaid).reduce(0, +)
      let historicalTotalVolume = historicalFuelRows.compactMap(\.fuelVolume).reduce(0, +)
      let globalHistoricalAvgCostPerLiter =
        historicalTotalVolume > 0 ? historicalTotalPaid / historicalTotalVolume : globalAvgCostPerLiter

      // Build historical fuel aggregation by vehicle.
      let historicalTripVehicleByTripId: [String: String] = historicalTrips.reduce(into: [:]) {
        partial, trip in
        guard let vehicleId = trip.vehicleId else { return }
        partial[trip.id] = vehicleId
      }
      var historicalFuelAggByVehicle: [String: (paid: Double, volume: Double)] = [:]
      for row in historicalFuelRows {
        guard
          let tripId = row.tripId,
          let vehicleId = historicalTripVehicleByTripId[tripId]
        else {
          continue
        }

        var current = historicalFuelAggByVehicle[vehicleId] ?? (0, 0)
        current.paid += row.amountPaid ?? 0
        current.volume += row.fuelVolume ?? 0
        historicalFuelAggByVehicle[vehicleId] = current
      }

      let historicalAvgCostPerLiterByVehicle = historicalFuelAggByVehicle.mapValues {
        aggregate in
        aggregate.volume > 0 ? aggregate.paid / aggregate.volume :
          globalHistoricalAvgCostPerLiter
      }

      let computedRows = vehicles.map { vehicle in
        let liters = litersByVehicle[vehicle.id, default: 0]
        let vehicleAvgCostPerLiter = avgCostPerLiterByVehicle[vehicle.id] ?? globalAvgCostPerLiter
        let spend = liters * vehicleAvgCostPerLiter
        // Value historical liters with historical cost per liter for accurate budget.
        let historicalAvgCost = historicalAvgCostPerLiterByVehicle[vehicle.id] ??
          globalHistoricalAvgCostPerLiter
        let historicalSpend =
          historicalLitersByVehicle[vehicle.id, default: 0] * historicalAvgCost
        let dailyHistoricalSpend = historicalSpend / Double(baselineDays)
        let budget = max(0, dailyHistoricalSpend * Double(reportDays) * 1.10)

        return Row(
          id: vehicle.id,
          plateNumber: vehicle.plateNumber,
          litersConsumed: liters,
          costPerLiter: vehicleAvgCostPerLiter,
          totalSpend: spend,
          budgetAllocated: budget
        )
      }

      guard fetchID == currentFetchID else { return }
      rows = computedRows
    } catch {
      guard fetchID == currentFetchID else { return }
      errorMessage = error.localizedDescription
    }
  }

  private static func buildManualFuelByTrip(from rows: [FuelPriceRow]) -> [String: Double] {
    var fuelByTrip: [String: Double] = [:]
    for row in rows {
      guard let tripId = row.tripId else { continue }
      fuelByTrip[tripId, default: 0] += row.fuelVolume ?? 0
    }
    return fuelByTrip
  }

  private static func reconcileFuelUsage(trip: TripFuelRow, manualFuelLiters: Double?) -> Double {
    // Three-step reconciliation inputs:
    // 1) Manual fuel entry from fuel_logs (trip-linked)
    // 2) GPS-distance-derived liters using a conservative fleet reference efficiency
    // 3) Trip-reported liters (slider/operator reported value)
    let manual = sanitizedFuel(manualFuelLiters)
    let gpsDerived = sanitizedFuel(
      trip.distanceKm.map { distanceKm in
        let referenceKmPerLiter = 8.0
        return distanceKm / referenceKmPerLiter
      }
    )
    let slider = sanitizedFuel(trip.fuelUsedLiters)

    let candidates = [manual, gpsDerived, slider].compactMap { $0 }
    guard !candidates.isEmpty else { return 0 }

    // Median keeps outliers from any single source from dominating.
    let sorted = candidates.sorted()
    if sorted.count == 1 {
      return sorted[0]
    }
    if sorted.count == 2 {
      return (sorted[0] + sorted[1]) / 2
    }
    return sorted[1]
  }

  private static func sanitizedFuel(_ liters: Double?) -> Double? {
    guard let liters, liters.isFinite, liters > 0 else { return nil }
    return liters
  }
}
