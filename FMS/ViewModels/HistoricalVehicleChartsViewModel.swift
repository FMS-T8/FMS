import Foundation
import Observation
import Supabase

@Observable
@MainActor
public final class HistoricalVehicleChartsViewModel {

  public struct VehicleOption: Identifiable {
    public let id: String
    public let plateNumber: String
  }

  public struct MetricPoint: Identifiable {
    public let id: String
    public let date: Date
    public let value: Double
    public let isAnomaly: Bool
  }

  public enum Metric: String, CaseIterable, Identifiable {
    case fuelConsumption = "Fuel Consumption"
    case speed = "Speed"
    case idleTime = "Idle Time"
    case engineHours = "Engine Hours"

    public var id: String { rawValue }

    public var unit: String {
      switch self {
      case .fuelConsumption:
        return "L"
      case .speed:
        return "km/h"
      case .idleTime:
        return "min"
      case .engineHours:
        return "h"
      }
    }
  }

  public enum DateWindow: String, CaseIterable, Identifiable {
    case days7 = "7 Days"
    case days30 = "30 Days"
    case days90 = "90 Days"
    case custom = "Custom"

    public var id: String { rawValue }
  }

  private struct VehicleRow: Decodable {
    let id: String
    let plateNumber: String

    enum CodingKeys: String, CodingKey {
      case id
      case plateNumber = "plate_number"
    }
  }

  private struct TripRow: Decodable {
    let id: String
    let startTime: Date?
    let fuelUsedLiters: Double?
    let actualDurationMinutes: Int?

    enum CodingKeys: String, CodingKey {
      case id
      case startTime = "start_time"
      case fuelUsedLiters = "fuel_used_liters"
      case actualDurationMinutes = "actual_duration_minutes"
    }
  }

  private struct TripGPSRow: Decodable {
    let tripId: String?
    let speed: Double?
    let recordedAt: Date?

    enum CodingKeys: String, CodingKey {
      case tripId = "trip_id"
      case speed
      case recordedAt = "recorded_at"
    }
  }

  public var vehicles: [VehicleOption] = []
  public var selectedVehicleId: String?
  public var selectedMetric: Metric = .fuelConsumption
  public var selectedWindow: DateWindow = .days30
  public var customStartDate: Date
  public var customEndDate: Date

  public var points: [MetricPoint] = []
  public var isLoading = false
  public var errorMessage: String?
  private var fetchGeneration: Int = 0

  public init() {
    let now = Date()
    customEndDate = now
    customStartDate = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
  }

  public var anomalyCount: Int {
    points.filter(\.isAnomaly).count
  }

  public var dateRangeLabel: String {
    let f = DateFormatter()
    f.dateStyle = .medium
    return "\(f.string(from: customStartDate)) - \(f.string(from: customEndDate))"
  }

  public func applyDateWindow() {
    let now = Date()
    switch selectedWindow {
    case .days7:
      customEndDate = now
      customStartDate = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
    case .days30:
      customEndDate = now
      customStartDate = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
    case .days90:
      customEndDate = now
      customStartDate = Calendar.current.date(byAdding: .day, value: -90, to: now) ?? now
    case .custom:
      break
    }
  }

  public func loadInitialData() async {
    await fetchVehicles()
    await fetchSeries()
  }

  public func fetchVehicles() async {
    do {
      let rows: [VehicleRow] = try await SupabaseService.shared.client
        .from("vehicles")
        .select("id, plate_number")
        .order("plate_number", ascending: true)
        .execute().value

      vehicles = rows.map { VehicleOption(id: $0.id, plateNumber: $0.plateNumber) }
      if selectedVehicleId == nil {
        selectedVehicleId = vehicles.first?.id
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  public func fetchSeries() async {
    guard let selectedVehicleId else {
      points = []
      return
    }

    fetchGeneration += 1
    let generation = fetchGeneration
    let metric = selectedMetric

    isLoading = true
    errorMessage = nil
    defer {
      if generation == fetchGeneration {
        isLoading = false
      }
    }

    do {
      let iso = ISO8601DateFormatter()
      let from = iso.string(from: customStartDate)
      let to = iso.string(from: Self.endOfDay(for: customEndDate))

      let trips: [TripRow] = try await SupabaseService.shared.client
        .from("trips")
        .select("id, start_time, fuel_used_liters, actual_duration_minutes")
        .eq("vehicle_id", value: selectedVehicleId)
        .gte("start_time", value: from)
        .lte("start_time", value: to)
        .order("start_time", ascending: true)
        .execute().value

      guard generation == fetchGeneration else { return }

      let tripIds = trips.map(\.id)
      var gpsRows: [TripGPSRow] = []
      if needsGPSRows(for: metric), !tripIds.isEmpty {
        gpsRows = try await SupabaseService.shared.client
          .from("trip_gps_logs")
          .select("trip_id, speed, recorded_at")
          .in("trip_id", values: tripIds)
          .gte("recorded_at", value: from)
          .lte("recorded_at", value: to)
          .execute().value
      }

      guard generation == fetchGeneration else { return }

      points = buildSeries(metric: metric, trips: trips, gpsRows: gpsRows)
    } catch {
      guard generation == fetchGeneration else { return }
      errorMessage = error.localizedDescription
    }
  }

  private func needsGPSRows(for metric: Metric) -> Bool {
    switch metric {
    case .speed, .idleTime:
      return true
    case .fuelConsumption, .engineHours:
      return false
    }
  }

  private static func endOfDay(for date: Date) -> Date {
    let calendar = Calendar.current
    return calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
  }

  private func buildSeries(metric: Metric, trips: [TripRow], gpsRows: [TripGPSRow]) -> [MetricPoint]
  {
    let calendar = Calendar.current

    func dayKey(_ date: Date) -> Date {
      calendar.startOfDay(for: date)
    }

    var valuesByDay: [Date: Double] = [:]

    switch metric {
    case .fuelConsumption:
      for trip in trips {
        guard let date = trip.startTime else { continue }
        valuesByDay[dayKey(date), default: 0] += trip.fuelUsedLiters ?? 0
      }

    case .engineHours:
      for trip in trips {
        guard let date = trip.startTime else { continue }
        let hours = Double(trip.actualDurationMinutes ?? 0) / 60.0
        valuesByDay[dayKey(date), default: 0] += max(0, hours)
      }

    case .speed:
      var speedSums: [Date: (sum: Double, count: Int)] = [:]
      for row in gpsRows {
        guard let date = row.recordedAt, let speed = row.speed else { continue }
        let key = dayKey(date)
        var aggregate = speedSums[key] ?? (0, 0)
        aggregate.sum += speed
        aggregate.count += 1
        speedSums[key] = aggregate
      }
      for (key, aggregate) in speedSums {
        valuesByDay[key] = aggregate.count > 0 ? aggregate.sum / Double(aggregate.count) : 0
      }

    case .idleTime:
      var idleSamples: [Date: Int] = [:]
      for row in gpsRows {
        guard let date = row.recordedAt, let speed = row.speed else { continue }
        if speed < 5 {
          idleSamples[dayKey(date), default: 0] += 1
        }
      }
      for (key, count) in idleSamples {
        // Approximate each idle log sample as one minute.
        valuesByDay[key] = Double(count)
      }
    }

    let sorted = valuesByDay.keys.sorted().map { key in
      MetricPoint(
        id: key.ISO8601Format(), date: key, value: valuesByDay[key] ?? 0, isAnomaly: false)
    }

    return markAnomalies(sorted)
  }

  private func markAnomalies(_ points: [MetricPoint]) -> [MetricPoint] {
    guard points.count > 2 else { return points }
    let values = points.map(\.value)
    let mean = values.reduce(0, +) / Double(values.count)
    let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
    let standardDeviation = sqrt(variance)
    guard standardDeviation > 0 else { return points }

    return points.map { point in
      let zDistance = abs(point.value - mean)
      return MetricPoint(
        id: point.id,
        date: point.date,
        value: point.value,
        isAnomaly: zDistance > (2 * standardDeviation)
      )
    }
  }
}
