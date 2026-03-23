import SwiftUI

/// A single row in the Fleet Utilization list showing vehicle hours and utilization bar.
public struct UtilizationRow: View {
    public let vehicle: FleetUtilization

    public init(vehicle: FleetUtilization) {
        self.vehicle = vehicle
    }

    private var tierColor: Color {
        switch vehicle.tier {
        case .high:   return FMSTheme.alertGreen
        case .medium: return FMSTheme.alertOrange
        case .low:    return FMSTheme.alertRed
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(vehicle.plateNumber)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FMSTheme.textPrimary)

                Spacer()

                Text(String(format: "%.0f%%", vehicle.utilizationPercent))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(tierColor)
            }

            // Utilization progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(FMSTheme.borderLight)
                        .frame(height: 8)

                    Capsule()
                        .fill(tierColor)
                        .frame(width: geo.size.width * max(min(vehicle.utilizationPercent / 100, 1.0), 0.0), height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Label(String(format: "%.0fh active", vehicle.activeHours), systemImage: "bolt.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(FMSTheme.textSecondary)

                Spacer()

                Label(String(format: "%.0fh available", vehicle.availableHours), systemImage: "clock")
                    .font(.system(size: 12))
                    .foregroundStyle(FMSTheme.textSecondary)
            }
        }
        .padding(14)
        .background(FMSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
    }
}
