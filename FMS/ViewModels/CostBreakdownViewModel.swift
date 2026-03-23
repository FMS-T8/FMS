import Foundation
import Observation
import Supabase

/// ViewModel for User Story 1: Monthly Cost Breakdown.
@Observable
public final class CostBreakdownViewModel {

  // MARK: - Published State
  public var summaries: [MonthlyCostSummary] = []
  public var isLoading = false
  public var errorMessage: String? = nil
  public var selectedRange: MonthRange = .six

  public enum MonthRange: Int, CaseIterable, Identifiable {
    case three = 3
    case six = 6
    case twelve = 12
    public var id: Int { rawValue }
    public var label: String { "Last \(rawValue)M" }
  }

  // MARK: - Computed

  /// Summaries trimmed to the selected time window.
  public var filteredSummaries: [MonthlyCostSummary] {
    Array(summaries.suffix(selectedRange.rawValue))
  }

  /// Month-over-month variance percentages (aligned with `filteredSummaries`).
  /// The first element is always `nil` because there is no prior month.
  public var variancePercentages: [Double?] {
    let items = filteredSummaries
    guard items.count > 1 else { return items.map { _ in nil } }
    var result: [Double?] = [nil]
    for i in 1..<items.count {
      let prev = items[i - 1].totalCost
      if prev == 0 {
        result.append(nil)
      } else {
        let change = ((items[i].totalCost - prev) / prev) * 100
        result.append(change)
      }
    }
    return result
  }

  // MARK: - Fetch

  @MainActor
  public func fetchCosts() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let fetched: [MonthlyCostSummary] = try await SupabaseService.shared.client
        .from("monthly_cost_summary")
        .select()
        .order("month", ascending: true)
        .execute()
        .value
      self.summaries = fetched
      #if DEBUG
        if let first = fetched.first {
          print(
            "Cost breakdown reports fetched: \(fetched.count). First row -> month: \(first.month), total: \(first.totalCost)"
          )
        } else {
          print("Cost breakdown reports fetched: 0 rows")
        }
      #endif
    } catch {
      self.errorMessage = error.localizedDescription
      #if DEBUG
        print("Error fetching cost summary: \(error)")
      #endif
    }
  }
}
