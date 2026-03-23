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
    
    // Maintenance
    public var activeMaintenanceCount: Int = 0
    public var completedMaintenanceCount: Int = 0
    
    // Helper types for lightweight parsing
    private struct IDRow: Decodable { let id: String }
    private struct TripRow: Decodable { let status: String?; let distance_km: Double? }
    private struct FuelRow: Decodable { let fuel_volume: Double?; let amount_paid: Double? }
    private struct StatusRow: Decodable { let status: String? }
    
    // MARK: - Init
    
    public init() {
        applyPresetDates()
    }
    
    private func applyPresetDates() {
        let cal = Calendar.current
        let now = Date()
        
        switch selectedPreset {
        case .thisWeek:
            // Assuming week starts on Monday for business logic
            var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            comps.weekday = 2 // Monday
            if let start = cal.date(from: comps) {
                startDate = start
                endDate = now // up to right now
            }
        case .lastWeek:
            var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            comps.weekOfYear = (comps.weekOfYear ?? 1) - 1
            comps.weekday = 2 // Monday
            if let start = cal.date(from: comps),
               let end = cal.date(byAdding: .day, value: 7, to: start)?.addingTimeInterval(-1) {
                startDate = start
                endDate = end
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
            
            // Fire all tasks in parallel
            async let tTrips: [TripRow] = tripsQ.execute().value
            async let tFuel: [FuelRow] = fuelQ.execute().value
            async let tIncidents: [IDRow] = incidentsQ.execute().value
            async let tEvents: [IDRow] = eventsQ.execute().value
            async let tMaintenance: [StatusRow] = maintenanceQ.execute().value
            
            let (trips, fuel, incidents, events, maintenance) =
                try await (tTrips, tFuel, tIncidents, tEvents, tMaintenance)
            
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
            
        } catch {
            self.errorMessage = "Failed to load report data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Email Subscription
    
    public func fetchSubscriptionStatus() async {
        do {
            let session = try await SupabaseService.shared.client.auth.session
            let userId = session.user.id.uuidString
            
            let response = try await SupabaseService.shared.client
                .from("report_email_subscriptions")
                .select()
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
            let subs = try JSONDecoder.supabase().decode([ReportEmailSubscription].self, from: response.data)
            
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
