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
  public var recentAlerts: [RecentAlert] = []
  public var isRecentAlertsLoaded: Bool = false
  public var errorMessage: String?

  public init() {}

  public func loadDashboardData() async {
    errorMessage = nil

    do {
      async let activeVehiclesTask: [IDRow] = SupabaseService.shared.client
        .from("vehicles")
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

  public func loadRecentAlerts() async {
    isRecentAlertsLoaded = false

    do {
      let session = try await SupabaseService.shared.client.auth.session
      let userId = session.user.id.uuidString

      let rows: [NotificationRow] = try await SupabaseService.shared.client
        .from("notifications")
        .select("id, type, message, created_at")
        .eq("recipient_id", value: userId)
        .order("created_at", ascending: false)
        .limit(5)
        .execute()
        .value

      self.recentAlerts = rows.compactMap { row in
        guard let message = row.message,
          !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          let timestamp = row.createdAt
        else {
          return nil
        }

        return RecentAlert(
          id: row.id,
          type: row.type ?? "info",
          message: message,
          timestamp: timestamp
        )
      }
      self.isRecentAlertsLoaded = true
    } catch {
      self.recentAlerts = []
      self.isRecentAlertsLoaded = false
    }
  }
}
