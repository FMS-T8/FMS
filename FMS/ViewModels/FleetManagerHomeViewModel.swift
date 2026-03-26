import Foundation
import Observation
import Supabase

@Observable
@MainActor
public final class FleetManagerHomeViewModel {
  public struct RecentAlert: Identifiable {
    public let id: String
    public let type: String
    public let message: String
    public let timestamp: Date
  }

  private struct IDRow: Decodable {
    let id: String
  }

  private struct NotificationRow: Decodable {
    let id: String
    let type: String?
    let message: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
      case id
      case type
      case message
      case createdAt = "created_at"
    }
  }

  public var managerName: String = "Manager"
  public var activeVehicleCount: Int = 0
  public var pendingOrderCount: Int = 0
  public var recentAlerts: [Notification] = []
  public var vehiclePlates: [String: String] = [:]
  public var errorMessage: String?

  // SOS specific state
  public var activeSOSAlerts: [SOSAlert] = []
  public var driverNames: [String: String] = [:] // ID to Name
  public var driverPhones: [String: String] = [:] // ID to Phone
  public var isFetchingSOS = false
  private var sosPollingTimer: Timer?

  public init() {}

  public func loadDashboardData() async {
    errorMessage = nil

    do {
      async let activeVehiclesTask: [IDRow] = SupabaseService.shared.client
        .from("trips")
        .select("id")
        .eq("status", value: "active")
        .execute()
        .value

      async let pendingOrdersTask: [IDRow] = SupabaseService.shared.client
        .from("orders")
        .select("id")
        .eq("status", value: "pending")
        .execute()
        .value

      let (activeVehicles, pendingOrders) = try await (activeVehiclesTask, pendingOrdersTask)
      self.activeVehicleCount = activeVehicles.count
      self.pendingOrderCount = pendingOrders.count

      // Fetch Recent Alerts
      await fetchRecentAlerts()

      if let userId = try? await SupabaseService.shared.client.auth.session.user.id.uuidString {
        struct UserNameRow: Decodable {
          let name: String
        }

        if let profile: UserNameRow = try? await SupabaseService.shared.client
          .from("users")
          .select("name")
          .eq("id", value: userId)
          .limit(1)
          .single()
          .execute()
          .value
        {
          self.managerName = profile.name
        }
      }
    } catch {
      self.errorMessage = error.localizedDescription
    }
  }

  public func fetchRecentAlerts() async {
    do {
      let alerts: [Notification] = try await SupabaseService.shared.client
        .from("notifications")
        .select()
        .order("created_at", ascending: false)
        .limit(10)
        .execute()
        .value
      self.recentAlerts = alerts
      
      // Fetch associated vehicle plates
      let vehicleIds = Array(Set(alerts.compactMap { $0.vehicleId }))
      if !vehicleIds.isEmpty {
        struct VehiclePlateRow: Decodable {
          let id: String
          let plate_number: String
        }
        
        let plates: [VehiclePlateRow] = try await SupabaseService.shared.client
          .from("vehicles")
          .select("id, plate_number")
          .in("id", values: vehicleIds)
          .execute()
          .value
        
        for row in plates {
          self.vehiclePlates[row.id] = row.plate_number
        }
      }
    } catch {
      print("[FMS] fetchRecentAlerts failed: \(error)")
    }
  }

  public func deleteNotification(id: String) async {
    do {
      try await SupabaseService.shared.client
        .from("notifications")
        .delete()
        .eq("id", value: id)
        .execute()
      
      // Update local state immediately for responsiveness
      self.recentAlerts.removeAll { $0.id == id }
    } catch {
      print("[FMS] deleteNotification failed: \(error)")
    }
  }

  // MARK: - SOS Management

  public func startSOSPolling() {
    Task { await fetchSOSAlerts() }
    sosPollingTimer?.invalidate()
    sosPollingTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
      Task { @MainActor in
        await self.fetchSOSAlerts()
      }
    }
  }

  public func stopSOSPolling() {
    sosPollingTimer?.invalidate()
    sosPollingTimer = nil
  }

  public func fetchSOSAlerts() async {
    guard !isFetchingSOS else { return }
    isFetchingSOS = true
    defer { isFetchingSOS = false }

    do {
      let response = try await SupabaseService.shared.client
        .from("sos_alerts")
        .select()
        .eq("status", value: SOSAlertStatus.active.rawValue)
        .order("timestamp", ascending: false)
        .limit(10)
        .execute()

      let alerts = try JSONDecoder.supabase().decode([SOSAlert].self, from: response.data)
      self.activeSOSAlerts = alerts
      
      // Resolve metadata for new alerts
      for alert in alerts {
        await resolveMetadata(for: alert)
      }
    } catch {
      print("[FMS] fetchSOSAlerts failed: \(error)")
    }
  }

  public func resolveSOSAlert(id: String) async {
    do {
      try await SupabaseService.shared.client
        .from("sos_alerts")
        .update(["status": SOSAlertStatus.resolved.rawValue])
        .eq("id", value: id)
        .execute()
      
      // Refresh list
      await fetchSOSAlerts()
    } catch {
      print("[FMS] resolveSOSAlert failed: \(error)")
    }
  }

  private func resolveMetadata(for alert: SOSAlert) async {
    // Resolve Driver Name & Phone
    if driverNames[alert.driverId] == nil || driverPhones[alert.driverId] == nil {
      struct UserRow: Decodable { 
        let name: String
        let phone: String?
      }
      if let row: UserRow = try? await SupabaseService.shared.client
        .from("users")
        .select("name, phone")
        .eq("id", value: alert.driverId)
        .single()
        .execute()
        .value {
        driverNames[alert.driverId] = row.name
        if let phone = row.phone {
          driverPhones[alert.driverId] = phone
        }
      }
  }
}
}