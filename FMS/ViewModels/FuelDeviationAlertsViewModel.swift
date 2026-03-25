import Foundation
import Observation
import Supabase

@Observable
@MainActor
public final class FuelDeviationAlertsViewModel {

  private actor DeviationRunGate {
    private var isRunning = false

    func beginIfIdle() -> Bool {
      guard !isRunning else { return false }
      isRunning = true
      return true
    }

    func end() {
      isRunning = false
    }
  }

  private struct TripRow: Decodable {
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

  private struct FuelLogRow: Decodable {
    let tripId: String?
    let fuelVolume: Double?

    enum CodingKeys: String, CodingKey {
      case tripId = "trip_id"
      case fuelVolume = "fuel_volume"
    }
  }

  private struct VehicleRow: Decodable {
    let id: String
    let plateNumber: String

    enum CodingKeys: String, CodingKey {
      case id
      case plateNumber = "plate_number"
    }
  }

  public var alerts: [FuelDeviationAlert] = []
  public var isLoading = false
  public var errorMessage: String?
  public var thresholdPercent: Double = 15

  private var pollingTimer: Timer?
  private let deviationRunGate = DeviationRunGate()

  private struct AlertStatusUpdatePayload: Encodable {
    let status: String
  }

  private struct AlertInsertPayload: Encodable {
    let vehicleId: String
    let vehicleLabel: String
    let currentRate: Double
    let baselineRate: Double
    let deviationPercent: Double
    let timestamp: String
    let status: String

    enum CodingKeys: String, CodingKey {
      case vehicleId = "vehicle_id"
      case vehicleLabel = "vehicle_label"
      case currentRate = "current_rate"
      case baselineRate = "baseline_rate"
      case deviationPercent = "deviation_percent"
      case timestamp
      case status
    }
  }

  public init() {}

  public func startPolling() {
    pollingTimer?.invalidate()
    Task { await runDeviationCheck() }
    pollingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
      Task { @MainActor in
        await self?.runDeviationCheck()
      }
    }
  }

  public func stopPolling() {
    pollingTimer?.invalidate()
    pollingTimer = nil
  }

  public func runDeviationCheck() async {
    guard await deviationRunGate.beginIfIdle() else { return }

    isLoading = true
    errorMessage = nil
    defer {
      isLoading = false
      Task { await deviationRunGate.end() }
    }

    do {
      let now = Date()
      guard
        let lookbackStart = Calendar.current.date(byAdding: .day, value: -60, to: now),
        let currentWindowStart = Calendar.current.date(byAdding: .day, value: -7, to: now),
        let baselineWindowStart = Calendar.current.date(byAdding: .day, value: -37, to: now)
      else {
        return
      }

      let iso = ISO8601DateFormatter()
      let from = iso.string(from: lookbackStart)
      let to = iso.string(from: now)

      async let tripsTask: [TripRow] = SupabaseService.shared.client
        .from("trips")
        .select("id, vehicle_id, distance_km, fuel_used_liters, start_time")
        .gte("start_time", value: from)
        .lte("start_time", value: to)
        .execute().value

      async let fuelLogsTask: [FuelLogRow] = SupabaseService.shared.client
        .from("fuel_logs")
        .select("trip_id, fuel_volume")
        .gte("logged_at", value: from)
        .lte("logged_at", value: to)
        .execute().value

      async let vehiclesTask: [VehicleRow] = SupabaseService.shared.client
        .from("vehicles")
        .select("id, plate_number")
        .execute().value

      let (tripRows, fuelLogs, vehicles) = try await (tripsTask, fuelLogsTask, vehiclesTask)
      let labelByVehicle = Dictionary(
        uniqueKeysWithValues: vehicles.map { ($0.id, $0.plateNumber) })

      let manualFuelByTrip = Self.buildManualFuelByTrip(from: fuelLogs)

      typealias Agg = (distance: Double, gpsFuel: Double, manualFuel: Double, sliderDelta: Double)
      var currentAgg: [String: Agg] = [:]
      var baselineAgg: [String: Agg] = [:]

      for row in tripRows {
        guard
          let vehicleId = row.vehicleId,
          let distance = row.distanceKm,
          let fuel = row.fuelUsedLiters,
          fuel > 0,
          let date = row.startTime
        else {
          continue
        }

        // NOTE: `sliderDelta` here is a derived consistency signal from `manualFuelByTrip`
        // (aggregated `FuelLog.fuelVolume`) versus trip fuel (`Trip.fuelUsedLiters`), not actual
        // slider telemetry. `FuelReceiptParserService` currently validates slider input but does not
        // persist it to `Trip` or `FuelLog`, so true slider-based verification is not yet available.
        let manualFuel = max(0, manualFuelByTrip[row.id] ?? 0)
        let sliderDelta = manualFuel > 0 ? abs(manualFuel - fuel) : 0

        if date >= currentWindowStart {
          let old = currentAgg[vehicleId] ?? (0, 0, 0, 0)
          currentAgg[vehicleId] = (
            old.distance + distance,
            old.gpsFuel + fuel,
            old.manualFuel + manualFuel,
            old.sliderDelta + sliderDelta
          )
        } else if date >= baselineWindowStart && date < currentWindowStart {
          let old = baselineAgg[vehicleId] ?? (0, 0, 0, 0)
          baselineAgg[vehicleId] = (
            old.distance + distance,
            old.gpsFuel + fuel,
            old.manualFuel + manualFuel,
            old.sliderDelta + sliderDelta
          )
        }
      }

      var nextAlerts: [FuelDeviationAlert] = []
      let existingByVehicle = Dictionary(uniqueKeysWithValues: alerts.map { ($0.vehicleId, $0) })
      for (vehicleId, current) in currentAgg {
        guard let baseline = baselineAgg[vehicleId], baseline.gpsFuel > 0 else { continue }

        let currentRate = current.distance / current.gpsFuel
        let baselineRate = baseline.distance / baseline.gpsFuel
        guard baselineRate > 0 else { continue }

        let deviation = ((currentRate - baselineRate) / baselineRate) * 100
        if verifyFuelDeviation(
          vehicleId: vehicleId,
          current: current,
          baseline: baseline,
          manualTotal: current.manualFuel,
          sliderDelta: current.sliderDelta,
          thresholdPercent: thresholdPercent
        ) {
          let existingStatus = existingByVehicle[vehicleId]?.status ?? .active
          let alert = FuelDeviationAlert(
            vehicleId: vehicleId,
            vehicleLabel: labelByVehicle[vehicleId] ?? vehicleId,
            currentRate: currentRate,
            baselineRate: baselineRate,
            deviationPercent: deviation,
            timestamp: now,
            status: existingStatus
          )

          // Persist only newly generated alerts; existing alerts are already in storage.
          if existingByVehicle[vehicleId] == nil {
            let insertPayload = AlertInsertPayload(
              vehicleId: alert.vehicleId,
              vehicleLabel: alert.vehicleLabel,
              currentRate: alert.currentRate,
              baselineRate: alert.baselineRate,
              deviationPercent: alert.deviationPercent,
              timestamp: iso.string(from: alert.timestamp),
              status: alert.status.rawValue
            )

            do {
              try await SupabaseService.shared.client
                .from("fuel_deviation_alerts")
                .insert(insertPayload)
                .execute()
            } catch {
              if errorMessage == nil {
                errorMessage = "Failed to persist one or more fuel deviation alerts."
              }
              continue
            }
          }

          nextAlerts.append(alert)
        }
      }

      alerts = nextAlerts.sorted { $0.timestamp > $1.timestamp }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private static func buildManualFuelByTrip(from rows: [FuelLogRow]) -> [String: Double] {
    var byTrip: [String: Double] = [:]
    for row in rows {
      guard let tripId = row.tripId else { continue }
      byTrip[tripId, default: 0] += row.fuelVolume ?? 0
    }
    return byTrip
  }

  private func verifyFuelDeviation(
    vehicleId: String,
    current: (distance: Double, gpsFuel: Double, manualFuel: Double, sliderDelta: Double),
    baseline: (distance: Double, gpsFuel: Double, manualFuel: Double, sliderDelta: Double),
    manualTotal: Double,
    sliderDelta: Double,
    thresholdPercent: Double
  ) -> Bool {
    _ = vehicleId
    _ = manualTotal
    _ = sliderDelta

    var votes = 0
    var availableSignals = 0

    // 1) GPS-derived efficiency signal (distance over trip fuel telemetry)
    if current.gpsFuel > 0, baseline.gpsFuel > 0 {
      availableSignals += 1
      let currentRate = current.distance / current.gpsFuel
      let baselineRate = baseline.distance / baseline.gpsFuel
      if baselineRate > 0 {
        let gpsDeviation = abs(((currentRate - baselineRate) / baselineRate) * 100)
        if gpsDeviation >= thresholdPercent { votes += 1 }
      }
    }

    // 2) Manual entry signal (fuel_logs)
    if current.manualFuel > 0, baseline.manualFuel > 0 {
      availableSignals += 1
      let currentRate = current.distance / current.manualFuel
      let baselineRate = baseline.distance / baseline.manualFuel
      if baselineRate > 0 {
        let manualDeviation = abs(((currentRate - baselineRate) / baselineRate) * 100)
        if manualDeviation >= thresholdPercent { votes += 1 }
      }
    }

    // 3) Fuel-slider telemetry consistency signal
    if baseline.sliderDelta > 0 {
      availableSignals += 1
      let sliderDeviation = abs(
        ((current.sliderDelta - baseline.sliderDelta) / baseline.sliderDelta) * 100)
      if sliderDeviation >= thresholdPercent { votes += 1 }
    }

    // Require at least two sources and two agreeing votes.
    return availableSignals >= 2 && votes >= 2
  }

  public func updateStatus(vehicleId: String, status: FuelDeviationAlertStatus) async {
    guard let index = alerts.firstIndex(where: { $0.vehicleId == vehicleId }) else { return }

    let previousStatus = alerts[index].status
    alerts[index].status = status

    do {
      try await SupabaseService.shared.client
        .from("fuel_deviation_alerts")
        .update(AlertStatusUpdatePayload(status: status.rawValue))
        .eq("vehicle_id", value: vehicleId)
        .execute()
      errorMessage = nil
    } catch {
      alerts[index].status = previousStatus
      errorMessage = "Failed to update alert status. Please try again."
    }
  }
}
