import Foundation
import Observation
import Supabase

@Observable
@MainActor
public final class FleetManagerHomeViewModel {
  private struct IDRow: Decodable {
    let id: String
  }

  public var managerName: String = "Manager"
  public var activeVehicleCount: Int = 0
  public var pendingOrderCount: Int = 0
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
        .in("status", values: ["pending", "confirmed", "dispatched"])
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
}
