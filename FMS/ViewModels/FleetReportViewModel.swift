import Foundation
import Observation
import Supabase

@MainActor
@Observable
public final class FleetReportViewModel {

  public struct DriverPerformance: Identifiable {
    public let id: String
    public let name: String
    public let behaviorScore: Double
    public let distanceKm: Double
    public let fuelLiters: Double
  }

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

  public var selectedWeekStart: Date = Date()

  // MARK: - Resource Lists (for pickers)
  public var availableVehicles: [LiveVehicleResource] = []
  public var availableDrivers: [LiveDriverResource] = []

  // MARK: - Data State
  public var isLoading: Bool = false
  public var errorMessage: String? = nil

  // Email Subscription State
  public var isSubscribedToEmail: Bool = false
  public var isTogglingSubscription: Bool = false
  private var subscriptionId: String? = nil

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

  // Driver Rankings
  public var topDrivers: [DriverPerformance] = []
  public var bottomDrivers: [DriverPerformance] = []
  public var averageBehaviorScore: Double = 0

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

  private struct DriverTripRow: Decodable {
    let driver_id: String?
    let distance_km: Double?
    let fuel_used_liters: Double?
  }

  private struct DriverAgg {
    var distance: Double = 0
    var fuel: Double = 0
    var incidents: Int = 0
    var events: Int = 0
  }

  // MARK: - Init

  public init() {
    applyPresetDates()
  }

  public var weekLabel: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd MMM"
    let weekEnd =
      Calendar.current.date(byAdding: .day, value: 6, to: selectedWeekStart) ?? selectedWeekStart
    return "\(formatter.string(from: selectedWeekStart)) - \(formatter.string(from: weekEnd))"
  }

  public static func monday(for date: Date) -> Date {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
    return calendar.date(from: components) ?? date
  }

  public func moveWeek(by value: Int) {
    guard
      let nextWeek = Calendar.current.date(byAdding: .day, value: value * 7, to: selectedWeekStart)
    else {
      return
    }
    selectedWeekStart = Self.monday(for: nextWeek)
    startDate = selectedWeekStart
    endDate =
      Calendar.current.date(byAdding: .day, value: 6, to: selectedWeekStart) ?? selectedWeekStart
    selectedPreset = .custom
  }

  private func applyPresetDates() {
    let cal = Calendar.current
    let now = Date()

    switch selectedPreset {
    case .thisWeek:
      let start = Self.monday(for: now)
      startDate = start
      endDate = cal.date(byAdding: .day, value: 6, to: start) ?? now
      selectedWeekStart = start
    case .lastWeek:
      let previousWeekDate = cal.date(byAdding: .day, value: -7, to: now) ?? now
      let start = Self.monday(for: previousWeekDate)
      startDate = start
      endDate = cal.date(byAdding: .day, value: 6, to: start) ?? now
      selectedWeekStart = start
    case .last30Days:
      if let start = cal.date(byAdding: .day, value: -30, to: now) {
        startDate = start
        endDate = now
        selectedWeekStart = Self.monday(for: start)
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

      // Driver ranking query intentionally includes only fields needed for scoring.
      var driverTripQ = builder.from("trips").select("driver_id, distance_km, fuel_used_liters")
        .gte("created_at", value: startStr)
        .lte("created_at", value: endStr)
      if let vId = selectedVehicleId { driverTripQ = driverTripQ.eq("vehicle_id", value: vId) }
      if let dId = selectedDriverId { driverTripQ = driverTripQ.eq("driver_id", value: dId) }

      let driverTrips: [DriverTripRow] = try await driverTripQ.execute().value

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

      // Build rankings using the unified incidents array
      buildDriverRanking(
        driverTrips: driverTrips, incidents: incidents, totalEventCount: events.count)

    } catch {
      self.errorMessage = "Failed to load report data: \(error.localizedDescription)"
    }
  }

  private func buildDriverRanking(
    driverTrips: [DriverTripRow], incidents: [IncidentRow], totalEventCount: Int
  ) {
    var byDriver: [String: DriverAgg] = [:]

    for row in driverTrips {
      guard let driverId = row.driver_id else { continue }
      var agg = byDriver[driverId] ?? DriverAgg()
      agg.distance += row.distance_km ?? 0
      agg.fuel += row.fuel_used_liters ?? 0
      byDriver[driverId] = agg
    }

    for incident in incidents {
      guard let driverId = incident.driver_id else { continue }
      var agg = byDriver[driverId] ?? DriverAgg()
      agg.incidents += 1
      byDriver[driverId] = agg
    }

    // vehicle_events table doesn't carry driver_id, so distribute as a light global penalty.
    let eventPenalty = byDriver.isEmpty ? 0 : Double(totalEventCount) / Double(byDriver.count)

    let nameByDriver = Dictionary(uniqueKeysWithValues: availableDrivers.map { ($0.id, $0.name) })

    let scored = byDriver.map { (driverId, agg) -> DriverPerformance in
      let efficiency = agg.fuel > 0 ? (agg.distance / agg.fuel) : 0
      let base = 70.0
      let efficiencyBoost = min(30.0, efficiency * 3.0)
      let incidentPenalty = Double(agg.incidents) * 12.0
      let safetyPenalty = eventPenalty * 6.0
      let score = max(0, min(100, base + efficiencyBoost - incidentPenalty - safetyPenalty))
      return DriverPerformance(
        id: driverId,
        name: nameByDriver[driverId] ?? "Driver \(driverId.prefix(6))",
        behaviorScore: score,
        distanceKm: agg.distance,
        fuelLiters: agg.fuel
      )
    }
    .sorted { $0.behaviorScore > $1.behaviorScore }

    topDrivers = Array(scored.prefix(5))
    bottomDrivers = Array(scored.suffix(5).reversed())
    averageBehaviorScore =
      scored.isEmpty ? 0 : scored.map(\.behaviorScore).reduce(0, +) / Double(scored.count)
  }

  public func weeklyCSVReport() -> String {
    let header = "section,driver_id,driver_name,behavior_score,distance_km,fuel_liters"

    let topLines = topDrivers.map {
      [
        csvField("top"),
        csvField($0.id),
        csvField($0.name),
        csvField(String(format: "%.2f", $0.behaviorScore)),
        csvField(String(format: "%.2f", $0.distanceKm)),
        csvField(String(format: "%.2f", $0.fuelLiters)),
      ].joined(separator: ",")
    }

    let bottomLines = bottomDrivers.map {
      [
        csvField("bottom"),
        csvField($0.id),
        csvField($0.name),
        csvField(String(format: "%.2f", $0.behaviorScore)),
        csvField(String(format: "%.2f", $0.distanceKm)),
        csvField(String(format: "%.2f", $0.fuelLiters)),
      ].joined(separator: ",")
    }

    let summary = [
      csvField("summary"),
      csvField(""),
      csvField(""),
      csvField(""),
      csvField("avg_behavior_score"),
      csvField(String(format: "%.2f", averageBehaviorScore)),
    ].joined(separator: ",")
    return ([header, summary] + topLines + bottomLines).joined(separator: "\n")
  }

  private func csvField(_ value: String) -> String {
    let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
    let requiresQuotes =
      escaped.contains(",") || escaped.contains("\n") || escaped.contains("\r")
      || escaped.contains("\"")
    return requiresQuotes ? "\"\(escaped)\"" : escaped
  }

  // MARK: - Email Subscription

  public func fetchSubscriptionStatus() async {
    do {
      let session = try await SupabaseService.shared.client.auth.session
      let userId = session.user.id.uuidString

      let subs: [ReportEmailSubscription] = try await SupabaseService.shared.client
        .from("report_email_subscriptions")
        .select()
        .eq("user_id", value: userId)
        .limit(1)
        .execute()
        .value

      if let sub = subs.first {
        self.subscriptionId = sub.id
        self.isSubscribedToEmail = sub.isActive
      } else {
        self.subscriptionId = nil
        self.isSubscribedToEmail = false
      }
    } catch {
      print("Failed to fetch email subscription: \(error)")
    }
  }

  public func syncEmailSubscription(_ newValue: Bool) async {
    guard !isTogglingSubscription else { return }
    isTogglingSubscription = true
    defer { isTogglingSubscription = false }

    do {
      let session = try await SupabaseService.shared.client.auth.session
      let userId = session.user.id.uuidString
      let userEmail = session.user.email ?? ""

      if let id = subscriptionId {
        struct UpdatePayload: Encodable { let is_active: Bool }
        try await SupabaseService.shared.client
          .from("report_email_subscriptions")
          .update(UpdatePayload(is_active: newValue))
          .eq("id", value: id)
          .execute()
      } else {
        struct InsertPayload: Encodable {
          let user_id: String
          let email: String
          let is_active: Bool
          let day_of_week: Int
        }
        let inserted: ReportEmailSubscription = try await SupabaseService.shared.client
          .from("report_email_subscriptions")
          .insert(
            InsertPayload(user_id: userId, email: userEmail, is_active: newValue, day_of_week: 1)
          )
          .select()
          .single()
          .execute()
          .value

        self.subscriptionId = inserted.id
      }

      self.isSubscribedToEmail = newValue
      self.errorMessage = nil
    } catch {
      self.errorMessage = "Could not update email subscription. Please try again."
      print("Failed to sync email sub: \(error)")
    }
  }

  private static func endOfDay(for date: Date) -> Date {
    let calendar = Calendar.current
    return calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
  }
}
