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
  private struct IDRow: Decodable {
    let id: String
    let driver_id: String?
  }
  private struct TripRow: Decodable {
    let status: String?
    let distance_km: Double?
  }
  private struct FuelRow: Decodable {
    let fuel_volume: Double?
    let amount_paid: Double?
  }
  private struct StatusRow: Decodable { let status: String? }
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
    selectedWeekStart = Self.monday(for: Date())
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
      // Assuming week starts on Monday for business logic
      var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
      comps.weekday = 2  // Monday
      if let start = cal.date(from: comps) {
        startDate = start
        endDate = cal.date(byAdding: .day, value: 6, to: start) ?? now
        selectedWeekStart = start
      }
    case .lastWeek:
      var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
      comps.weekOfYear = (comps.weekOfYear ?? 1) - 1
      comps.weekday = 2  // Monday
      if let start = cal.date(from: comps),
        let end = cal.date(byAdding: .day, value: 7, to: start)?.addingTimeInterval(-1)
      {
        startDate = start
        endDate = end
        selectedWeekStart = start
      }
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
    let endStr = isoFormatter.string(from: endDate)

    do {
      // Because vehicle_events uses text type for vehicle_id instead of uuid natively, we need to pass a string.
      // All other tables accept standard uuid equality.
      let builder = SupabaseService.shared.client

      // 1. TRIPS (using created_at)
      var tripsQ = builder.from("trips").select("status, distance_km")
        .gte("created_at", value: startStr)
        .lte("created_at", value: endStr)
      if let vId = selectedVehicleId { tripsQ = tripsQ.eq("vehicle_id", value: vId) }
      if let dId = selectedDriverId { tripsQ = tripsQ.eq("driver_id", value: dId) }

      // 2. FUEL LOGS (using logged_at)
      // Note: fuel_logs lacks vehicle_id. If a vehicle is selected, we can't reliably filter it directly
      // unless we only use driver filters. We apply the driver filter if present.
      var fuelQ = builder.from("fuel_logs").select("fuel_volume, amount_paid")
        .gte("logged_at", value: startStr)
        .lte("logged_at", value: endStr)
      if let dId = selectedDriverId { fuelQ = fuelQ.eq("driver_id", value: dId) }

      // 3. INCIDENTS (using created_at)
      var incidentsQ = builder.from("incidents").select("id")
        .gte("created_at", value: startStr)
        .lte("created_at", value: endStr)
      if let vId = selectedVehicleId { incidentsQ = incidentsQ.eq("vehicle_id", value: vId) }
      if let dId = selectedDriverId { incidentsQ = incidentsQ.eq("driver_id", value: dId) }

      // 4. VEHICLE EVENTS (using timestamp, text vehicle_id)
      var eventsQ = builder.from("vehicle_events").select("id")
        .gte("timestamp", value: startStr)
        .lte("timestamp", value: endStr)
        .in("event_type", values: ["HarshBraking", "RapidAcceleration"])
      if let vId = selectedVehicleId { eventsQ = eventsQ.eq("vehicle_id", value: vId) }
      // vehicle_events lacks driver_id

      // 5. MAINTENANCE (using created_at)
      var maintenanceQ = builder.from("maintenance_work_orders").select("status")
        .gte("created_at", value: startStr)
        .lte("created_at", value: endStr)
      if let vId = selectedVehicleId { maintenanceQ = maintenanceQ.eq("vehicle_id", value: vId) }
      // lacks driver_id mapping natively on this table (only assigned_to/created_by)

      let trips: [TripRow] = try await tripsQ.execute().value
      let fuel: [FuelRow] = try await fuelQ.execute().value
      let incidents: [IDRow] = try await incidentsQ.execute().value
      let events: [IDRow] = try await eventsQ.execute().value
      let maintenance: [StatusRow] = try await maintenanceQ.execute().value

      // Driver ranking query intentionally includes only fields needed for scoring.
      var driverTripQ = builder.from("trips").select("driver_id, distance_km, fuel_used_liters")
        .gte("created_at", value: startStr)
        .lte("created_at", value: endStr)
      if let vId = selectedVehicleId { driverTripQ = driverTripQ.eq("vehicle_id", value: vId) }
      if let dId = selectedDriverId { driverTripQ = driverTripQ.eq("driver_id", value: dId) }

      var driverIncidentsQ = builder.from("incidents").select("id, driver_id")
        .gte("created_at", value: startStr)
        .lte("created_at", value: endStr)
      if let vId = selectedVehicleId {
        driverIncidentsQ = driverIncidentsQ.eq("vehicle_id", value: vId)
      }
      if let dId = selectedDriverId {
        driverIncidentsQ = driverIncidentsQ.eq("driver_id", value: dId)
      }

      let driverTrips: [DriverTripRow] = try await driverTripQ.execute().value
      let driverIncidents: [IDRow] = try await driverIncidentsQ.execute().value

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

      buildDriverRanking(
        driverTrips: driverTrips, incidents: driverIncidents, totalEventCount: events.count)

    } catch {
      self.errorMessage = "Failed to load report data: \(error.localizedDescription)"
    }
  }

  private func buildDriverRanking(
    driverTrips: [DriverTripRow], incidents: [IDRow], totalEventCount: Int
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
      "top,\($0.id),\($0.name),\(String(format: "%.2f", $0.behaviorScore)),\(String(format: "%.2f", $0.distanceKm)),\(String(format: "%.2f", $0.fuelLiters))"
    }

    let bottomLines = bottomDrivers.map {
      "bottom,\($0.id),\($0.name),\(String(format: "%.2f", $0.behaviorScore)),\(String(format: "%.2f", $0.distanceKm)),\(String(format: "%.2f", $0.fuelLiters))"
    }

    let summary = "summary,,,,avg_behavior_score,\(String(format: "%.2f", averageBehaviorScore))"
    return ([header, summary] + topLines + bottomLines).joined(separator: "\n")
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
    isTogglingSubscription = true
    defer { isTogglingSubscription = false }

    // MOCK FOR UI TESTING:
    // Because the backend table isn't set up yet, we'll mock the network delay.
    // The UI state is already instantly updated via the View's Binding.
    // If this backend call failed, we would revert it: `self.isSubscribedToEmail = !newValue`
    try? await Task.sleep(nanoseconds: 500_000_000)

    /* --- DEFERRED REAL SUPABASE IMPLEMENTATION ---
    do {
        let session = try await SupabaseService.shared.client.auth.session
        let userId = session.user.id.uuidString
        let userEmail = session.user.email ?? ""
    
        if let id = subscriptionId {
            // Update existing
            struct UpdatePayload: Encodable { let is_active: Bool }
            try await SupabaseService.shared.client
                .from("report_email_subscriptions")
                .update(UpdatePayload(is_active: newValue))
                .eq("id", value: id)
                .execute()
        } else {
            // Insert new
            struct InsertPayload: Encodable { let user_id: String; let email: String; let is_active: Bool }
            let inserted: ReportEmailSubscription = try await SupabaseService.shared.client
                .from("report_email_subscriptions")
                .insert(InsertPayload(user_id: userId, email: userEmail, is_active: newValue))
                .select()
                .single()
                .execute()
                .value
    
            self.subscriptionId = inserted.id
        }
    } catch {
        print("Failed to sync email sub: \(error)")
        // Revert UI on failure
        self.isSubscribedToEmail = !newValue
    }
    */
  }
}
