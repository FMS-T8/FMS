import SwiftUI

/// A single row in the Fuel Efficiency list showing plate, km/L gauge, and color indicator.
public struct EfficiencyRow: View {
  public let vehicle: VehicleFuelEfficiency

  public init(vehicle: VehicleFuelEfficiency) {
    self.vehicle = vehicle
  }

  private var tierColor: Color {
    switch vehicle.tier {
    case .good: return FMSTheme.alertGreen
    case .moderate: return FMSTheme.alertYellow
    case .poor: return FMSTheme.alertRed
    }
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        // Color dot
        Circle()
          .fill(tierColor)
          .frame(width: 10, height: 10)

        Text(vehicle.plateNumber)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(FMSTheme.textPrimary)

        Spacer()

        Text(String(format: "%.1f km/L", vehicle.kmPerLiter))
          .font(.system(size: 15, weight: .bold, design: .rounded))
          .foregroundStyle(tierColor)
      }

      HStack(spacing: 10) {
        Text(
          vehicle.baselineKmPerLiter.map {
            String(format: "Baseline %.1f km/L", $0)
          } ?? "Baseline N/A"
        )
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(FMSTheme.textSecondary)

        Spacer()

        let diff = vehicle.percentDifference
        Text(String(format: "%+.1f%%", diff))
          .font(.system(size: 12, weight: .bold, design: .rounded))
          .foregroundStyle(diff >= 0 ? FMSTheme.alertGreen : FMSTheme.alertRed)
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(
            (diff >= 0 ? FMSTheme.alertGreen : FMSTheme.alertRed).opacity(0.15),
            in: Capsule()
          )
      }

      // Linear gauge 0–20
      Gauge(value: min(vehicle.kmPerLiter, 20), in: 0...20) {
        EmptyView()
      }
      .gaugeStyle(.accessoryLinear)
      .tint(tierColor)

      HStack {
        Text("\(vehicle.totalTrips) trips")
          .font(.system(size: 12))
          .foregroundStyle(FMSTheme.textSecondary)
        Spacer()
      }
    }
    .padding(14)
    .background(FMSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
  }
}
