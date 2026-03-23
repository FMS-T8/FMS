import Foundation

/// Maps the `monthly_cost_summary` Supabase view.
public struct MonthlyCostSummary: Decodable, Identifiable {
    public var id: String { month }
    public let month: String          // e.g. "2026-01"
    public let fuelCost: Double
    public let maintenanceCost: Double
    public let totalCost: Double

    enum CodingKeys: String, CodingKey {
        case month
        case fuelCost = "fuel_cost"
        case maintenanceCost = "maintenance_cost"
        case totalCost = "total_cost"
    }

    /// Parsed display label, e.g. "Jan 26"
    public var displayMonth: String {
        let parts = month.split(separator: "-")
        guard parts.count >= 2,
              let monthNum = Int(parts[1]) else { return month }
        let symbols = Calendar.current.shortMonthSymbols
        guard monthNum >= 1, monthNum <= symbols.count else { return month }
        let label = symbols[monthNum - 1]
        let year = String(parts[0].suffix(2))
        return "\(label) \(year)"
    }
}
