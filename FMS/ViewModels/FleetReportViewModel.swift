import Foundation
import Observation
import Supabase

@MainActor
@Observable
public final class FleetReportViewModel {

  // MARK: - Filter State

  public enum DatePreset: String, CaseIterable, Identifiable {
    case thisWeek = "This Week"
    case lastWeek = "Last Week"
    case last30Days = "Last 30 Days"
    case custom = "Custom"
    public var id: String { rawValue }
  }

  public var selectedPreset: DatePreset = .thisWeek {
    didSet {
      if selectedPreset != .custom {
        applyPresetDates()
      }
    }
  }

  public var startDate: Date = Date()
  public var endDate: Date = Date()

  public var selectedVehicleId: String? = nil
  public var selectedDriverId: String? = nil

  // MARK: - Resource Lists (for pickers)
  public var availableVehicles: [LiveVehicleResource] = []
  public var availableDrivers: [LiveDriverResource] = []

  // MARK: - Data State
  public var isLoading: Bool = false
  public var errorMessage: String? = nil

  // MARK: - Detailed Arrays (for expanding views)
  public var tripsData: [TripRow] = []
  public var fuelData: [FuelRow] = []
  public var incidentsData: [IncidentRow] = []
  public var eventsData: [EventRow] = []
  public var maintenanceData: [MaintenanceRow] = []

  // MARK: - Computed KPIs

  // Trip Metrics
  public var totalTrips: Int = 0
  public var completedTrips: Int = 0
  public var totalDistanceKm: Double = 0.0

  // Fuel Metrics
  public var totalFuelLiters: Double = 0.0
  public var totalFuelCost: Double = 0.0
  public var avgFuelEfficiency: Double {
    guard totalFuelLiters > 0 else { return 0.0 }
    return totalDistanceKm / totalFuelLiters
  }

  // Safety
  public var incidentCount: Int = 0
  public var safetyEventCount: Int = 0

  // Maintenance
  public var activeMaintenanceCount: Int = 0
  public var completedMaintenanceCount: Int = 0

  // Helper types for lightweight parsing
  public struct IDRow: Decodable, Identifiable, Hashable { public let id: String; public let driver_id: String? }
  public struct TripRow: Decodable, Identifiable, Hashable { public let id: String; public let status: String?; public let distance_km: Double?; public let shipment_description: String? }
  public struct FuelRow: Decodable, Identifiable, Hashable { public let id: String; public let fuel_volume: Double?; public let amount_paid: Double?; public let fuel_station: String?; public let logged_at: String?; public let driver_id: String? }
  public struct StatusRow: Decodable, Identifiable, Hashable { public let id: String; public let status: String? }
  public struct IncidentRow: Decodable, Identifiable, Hashable { public let id: String; public let severity: String?; public let created_at: String?; public let driver_id: String? }
  public struct EventRow: Decodable, Identifiable, Hashable { public let id: String; public let event_type: String?; public let timestamp: String? }
  public struct MaintenanceRow: Decodable, Identifiable, Hashable { public let id: String; public let description: String?; public let priority: String?; public let status: String?; public let estimated_cost: Double?; public let created_at: String? }

  // MARK: - Init

  public init() {
    applyPresetDates()
  }

  public var dateLabel: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd MMM"
    return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
  }

  public static func monday(for date: Date) -> Date {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
    return calendar.date(from: components) ?? date
  }

  public func moveDateRange(by value: Int) {
    let span = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 6
    if let nextStart = Calendar.current.date(byAdding: .day, value: value * (span + 1), to: startDate) {
      startDate = nextStart
      endDate = Calendar.current.date(byAdding: .day, value: span, to: startDate) ?? nextStart
      detectPreset()
    }
  }

  private func detectPreset() {
    let cal = Calendar.current
    let now = Date()

    let thisWeekStart = Self.monday(for: now)
    let thisWeekEnd = cal.date(byAdding: .day, value: 6, to: thisWeekStart) ?? now
    if isSameDay(startDate, thisWeekStart) && isSameDay(endDate, thisWeekEnd) {
      selectedPreset = .thisWeek
      return
    }

    let previousWeekDate = cal.date(byAdding: .day, value: -7, to: now) ?? now
    let lastWeekStart = Self.monday(for: previousWeekDate)
    let lastWeekEnd = cal.date(byAdding: .day, value: 6, to: lastWeekStart) ?? now
    if isSameDay(startDate, lastWeekStart) && isSameDay(endDate, lastWeekEnd) {
      selectedPreset = .lastWeek
      return
    }

    if let last30Start = cal.date(byAdding: .day, value: -30, to: now),
       isSameDay(startDate, last30Start) && isSameDay(endDate, now) {
      selectedPreset = .last30Days
      return
    }

    selectedPreset = .custom
  }

  private func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
    Calendar.current.isDate(date1, inSameDayAs: date2)
  }

  private func applyPresetDates() {
    let cal = Calendar.current
    let now = Date()

    switch selectedPreset {
    case .thisWeek:
      let start = Self.monday(for: now)
      startDate = start
      endDate = cal.date(byAdding: .day, value: 6, to: start) ?? now
    case .lastWeek:
      let previousWeekDate = cal.date(byAdding: .day, value: -7, to: now) ?? now
      let start = Self.monday(for: previousWeekDate)
      startDate = start
      endDate = cal.date(byAdding: .day, value: 6, to: start) ?? now
    case .last30Days:
      if let start = cal.date(byAdding: .day, value: -30, to: now) {
        startDate = start
        endDate = now
      }
    case .custom:
      break
    }
  }

  // MARK: - Fetchers

  public func loadFilters() async {
    do {
      async let vehiclesTask: [LiveVehicleResource] = SupabaseService.shared.client
        .from("vehicles")
        .select("id, plate_number, manufacturer, model")
        .eq("status", value: "active")
        .execute().value

      async let driversTask: [LiveDriverResource] = SupabaseService.shared.client
        .from("users")
        .select("id, name")
        .eq("role", value: "driver")
        .eq("is_deleted", value: false)
        .execute().value

      let (v, d) = try await (vehiclesTask, driversTask)
      self.availableVehicles = v
      self.availableDrivers = d
    } catch {
      print("Failed to load filter items: \(error)")
    }
  }

  public func fetchReportData() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    // Formatter for Supabase ISO queries
    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let startStr = isoFormatter.string(from: startDate)
    let endStr = isoFormatter.string(from: Self.endOfDay(for: endDate))

    do {
      // Because vehicle_events uses text type for vehicle_id instead of uuid natively, we need to pass a string.
      // All other tables accept standard uuid equality.
      let builder = SupabaseService.shared.client

      // 1. TRIPS
      var tripsQ = builder.from("trips").select("id, status, distance_km, shipment_description")
        .gte("created_at", value: startStr)
        .lte("created_at", value: endStr)
      if let vId = selectedVehicleId { tripsQ = tripsQ.eq("vehicle_id", value: vId) }
      if let dId = selectedDriverId { tripsQ = tripsQ.eq("driver_id", value: dId) }

      // 2. FUEL LOGS
      let canScopeFuelMetrics = selectedVehicleId == nil || selectedDriverId != nil
      let fuel: [FuelRow]
      if canScopeFuelMetrics {
        var fuelQ = builder.from("fuel_logs").select("id, fuel_volume, amount_paid, fuel_station, logged_at, driver_id")
          .gte("logged_at", value: startStr)
          .lte("logged_at", value: endStr)
        if let dId = selectedDriverId { fuelQ = fuelQ.eq("driver_id", value: dId) }
        fuel = try await fuelQ.execute().value
      } else {
        fuel = []
      }

      // 3. INCIDENTS
      // driver ranking also needs incident count
      var incidentsQ = builder.from("incidents").select("id, severity, created_at, driver_id")
        .gte("created_at", value: startStr)
        .lte("created_at", value: endStr)
      if let vId = selectedVehicleId { incidentsQ = incidentsQ.eq("vehicle_id", value: vId) }
      if let dId = selectedDriverId { incidentsQ = incidentsQ.eq("driver_id", value: dId) }

      let canScopeSafetyEvents = selectedDriverId == nil
      let canScopeMaintenance = selectedDriverId == nil

      let events: [EventRow]
      if canScopeSafetyEvents {
        var eventsQ = builder.from("vehicle_events").select("id, event_type, timestamp")
          .gte("timestamp", value: startStr)
          .lte("timestamp", value: endStr)
          .in("event_type", values: ["HarshBraking", "RapidAcceleration", "GeofenceBreach", "ZoneBreach"])
        if let vId = selectedVehicleId { eventsQ = eventsQ.eq("vehicle_id", value: vId) }
        events = try await eventsQ.execute().value
      } else {
        events = []
      }

      let maintenance: [MaintenanceRow]
      if canScopeMaintenance {
        var maintenanceQ = builder.from("maintenance_work_orders").select("id, status, description, priority, estimated_cost, created_at")
          .gte("created_at", value: startStr)
          .lte("created_at", value: endStr)
        if let vId = selectedVehicleId { maintenanceQ = maintenanceQ.eq("vehicle_id", value: vId) }
        maintenance = try await maintenanceQ.execute().value
      } else {
        maintenance = []
      }

      let trips: [TripRow] = try await tripsQ.execute().value
      let incidents: [IncidentRow] = try await incidentsQ.execute().value

      // Perform Aggregations
      self.totalTrips = trips.count
      self.completedTrips = trips.filter { $0.status == "completed" }.count
      self.totalDistanceKm = trips.compactMap(\.distance_km).reduce(0, +)

      self.totalFuelLiters = fuel.compactMap(\.fuel_volume).reduce(0, +)
      self.totalFuelCost = fuel.compactMap(\.amount_paid).reduce(0, +)

      self.incidentCount = incidents.count
      self.safetyEventCount = events.count

      self.activeMaintenanceCount = maintenance.filter { $0.status != "completed" }.count
      self.completedMaintenanceCount = maintenance.filter { $0.status == "completed" }.count

      self.tripsData = trips
      self.fuelData = fuel
      self.incidentsData = incidents
      self.eventsData = events
      self.maintenanceData = maintenance

    } catch {
      self.errorMessage = "Failed to load report data: \(error.localizedDescription)"
    }
  }

  public func weeklyCSVReport() -> String {
    let header = "metric,value"

    let summary = [
      ["Total Trips", "\(totalTrips)"],
      ["Completed Trips", "\(completedTrips)"],
      ["Distance Traveled (km)", String(format: "%.1f", totalDistanceKm)],
      ["Total Fuel Liter", String(format: "%.1f", totalFuelLiters)],
      ["Total Fuel Cost", String(format: "%.0f", totalFuelCost)],
      ["Total Incidents", "\(incidentCount)"],
      ["Safety Events", "\(safetyEventCount)"],
      ["Active Maintenances", "\(activeMaintenanceCount)"]
    ]

    let csvLines = summary.map { row in
      row.map { csvField($0) }.joined(separator: ",")
    }

    return ([header] + csvLines).joined(separator: "\n")
  }

  private func csvField(_ value: String) -> String {
    let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
    let requiresQuotes =
      escaped.contains(",") || escaped.contains("\n") || escaped.contains("\r")
      || escaped.contains("\"")
    return requiresQuotes ? "\"\(escaped)\"" : escaped
  }

  private static func endOfDay(for date: Date) -> Date {
    let calendar = Calendar.current
    return calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
  }
}
