import SwiftUI

/// Hub view that provides navigation links to all 4 Fleet Manager analytics reports.
public struct ReportsHubView: View {

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    reportCard(
                        icon: "chart.bar.fill",
                        title: "Cost Breakdown",
                        subtitle: "Monthly fuel & maintenance costs with trend analysis",
                        color: FMSTheme.alertOrange,
                        destination: CostBreakdownView()
                    )

                    reportCard(
                        icon: "fuelpump.fill",
                        title: "Fuel Efficiency",
                        subtitle: "Vehicle km/L ratings and efficiency rankings",
                        color: FMSTheme.alertGreen,
                        destination: FuelEfficiencyView()
                    )

                    reportCard(
                        icon: "doc.text.fill",
                        title: "Historical Reports",
                        subtitle: "Trip history with date filtering and CSV export",
                        color: FMSTheme.amber,
                        destination: HistoricalReportsView()
                    )

                    reportCard(
                        icon: "gauge.with.dots.needle.67percent",
                        title: "Fleet Utilization",
                        subtitle: "Active hours, idle time, and utilization rates",
                        color: FMSTheme.alertRed,
                        destination: FleetUtilizationView()
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(FMSTheme.backgroundPrimary)
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Card Builder

    private func reportCard<Destination: View>(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        destination: Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FMSTheme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(FMSTheme.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FMSTheme.textTertiary)
            }
            .padding(16)
            .background(FMSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: FMSTheme.shadowSmall, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}
