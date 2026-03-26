import Foundation
import Observation
import PostgREST
import Supabase

/// ViewModel for consolidated spend analytics.
@Observable
public final class CostBreakdownViewModel {

  private struct FuelCostRow: Decodable {
    let amountPaid: Double?
    let loggedAt: Date?

    enum CodingKeys: String, CodingKey {
      case amountPaid = "amount_paid"
      case loggedAt = "logged_at"
    }
  }

  private struct MaintenanceCostRow: Decodable {
    let estimatedCost: Double?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
      case estimatedCost = "estimated_cost"
      case createdAt = "created_at"
    }
  }

  private struct TollCostRow: Decodable {
    let amount: Double?
    let paidAt: Date?

    enum CodingKeys: String, CodingKey {
      case amount
      case paidAt = "paid_at"
    }
  }

  // MARK: - State
  public var fuelSpend: Double = 0
  public var maintenanceSpend: Double = 0
  public var tollSpend: Double = 0
  public var isLoading = false
  public var errorMessage: String? = nil
  public var selectedRange: DateRange = .thisMonth {
    didSet {
      guard selectedRange != .custom else { return }
      applyRangePreset(selectedRange)
    }
  }
  public var customStartDate: Date
  public var customEndDate: Date

  public enum DateRange: String, CaseIterable, Identifiable {
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case custom = "Custom"

    public var id: String { rawValue }
  }

  public init() {
    let now = Date()
    let calendar = Calendar.current
    let startOfMonth =
      calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
    self.customStartDate = startOfMonth
    self.customEndDate = now
  }

  // MARK: - Computed

  public var grandTotal: Double {
    fuelSpend + maintenanceSpend + tollSpend
  }

  public struct SpendSlice: Identifiable {
    public let id: String
    public let label: String
    public let amount: Double
  }

  public var spendBreakdown: [SpendSlice] {
    [
      .init(id: "fuel", label: "Fuel", amount: fuelSpend),
      .init(id: "maintenance", label: "Maintenance", amount: maintenanceSpend),
      .init(id: "tolls", label: "Tolls", amount: tollSpend),
    ]
  }

  public var dateRangeLabel: String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return "\(formatter.string(from: customStartDate)) - \(formatter.string(from: customEndDate))"
  }

  private func applyRangePreset(_ preset: DateRange) {
    let calendar = Calendar.current
    let now = Date()

    switch preset {
    case .thisWeek:
      let weekStart =
        calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))
        ?? now
      customStartDate = weekStart
      customEndDate = now
    case .thisMonth:
      let monthStart =
        calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
      customStartDate = monthStart
      customEndDate = now
    case .custom:
      break
    }
  }

  // MARK: - Fetch

  @MainActor
  public func fetchCosts() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let iso = ISO8601DateFormatter()
      let start = iso.string(from: customStartDate)
      let end = iso.string(from: customEndDate)

      async let fuelTask: [FuelCostRow] = SupabaseService.shared.client
        .from("fuel_logs")
        .select("amount_paid, logged_at")
        .gte("logged_at", value: start)
        .lte("logged_at", value: end)
        .execute()
        .value

      async let maintenanceTask: [MaintenanceCostRow] = SupabaseService.shared.client
        .from("maintenance_work_orders")
        .select("estimated_cost, created_at")
        .gte("created_at", value: start)
        .lte("created_at", value: end)
        .execute()
        .value

      let (fuelRows, maintenanceRows) = try await (fuelTask, maintenanceTask)
      self.fuelSpend = fuelRows.compactMap(\.amountPaid).reduce(0, +)
      self.maintenanceSpend = maintenanceRows.compactMap(\.estimatedCost).reduce(0, +)

      // `toll_logs` is optional in some environments. Fallback to zero if absent.
      do {
        let tollRows: [TollCostRow] = try await SupabaseService.shared.client
          .from("toll_logs")
          .select("amount, paid_at")
          .gte("paid_at", value: start)
          .lte("paid_at", value: end)
          .execute()
          .value
        self.tollSpend = tollRows.compactMap(\.amount).reduce(0, +)
      } catch {
        if isMissingTableError(error, tableName: "toll_logs") {
          self.tollSpend = 0
        } else {
          throw error
        }
      }

    } catch {
      self.errorMessage = error.localizedDescription
      #if DEBUG
        print("Error fetching cost summary: \(error)")
      #endif
    }
  }

  private func isMissingTableError(_ error: Error, tableName: String) -> Bool {
    let message = String(describing: error).lowercased()
    let table = tableName.lowercased()

    if message.contains("42p01") && message.contains(table) {
      return true
    }

    if message.contains("schema cache") && message.contains(table) {
      return true
    }

    if message.contains("does not exist") && message.contains(table) {
      return true
    }

    if let postgrestError = error as? PostgrestError {
      let postgrestMessage = String(describing: postgrestError).lowercased()
      return postgrestMessage.contains(table)
        && (postgrestMessage.contains("42p01")
          || postgrestMessage.contains("schema cache")
          || postgrestMessage.contains("does not exist"))
    }

    return false
  }
}
