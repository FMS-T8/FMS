import SwiftUI

/// Hub view that provides navigation links to all 4 Fleet Manager analytics reports.
public struct ReportsHubView: View {

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                FMSTheme.backgroundPrimary.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Reports")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(FMSTheme.textPrimary)
                        
                        reportCard(
                            icon: "chart.bar.fill",
                            title: "Spend Dashboard",
                            subtitle: "Fuel + maintenance + tolls consolidated by date range",
                            color: FMSTheme.alertOrange,
                            destination: CostBreakdownView()
                        )
                        
                        reportCard(
                            icon: "fuelpump.fill",
                            title: "Fuel Efficiency",
                            subtitle: "Vehicle km/L vs baseline with variance indicators",
                            color: FMSTheme.alertGreen,
                            destination: FuelEfficiencyView()
                        )
                        
                        reportCard(
                            icon: "doc.text.fill",
                            title: "Weekly Performance",
                            subtitle: "Mon-Sun summaries, driver scores, and export",
                            color: FMSTheme.amber,
                            destination: FleetReportView()
                        )
                        
                        reportCard(
                            icon: "banknote",
                            title: "Fuel Cost Report",
                            subtitle: "Per-vehicle fuel spend vs budget variance",
                            color: FMSTheme.alertRed,
                            destination: FuelCostReportView()
                        )
                        
                        reportCard(
                            icon: "exclamationmark.octagon.fill",
                            title: "Fuel Deviation Alerts",
                            subtitle: "Track baseline consumption deviations and resolve alerts",
                            color: FMSTheme.alertOrange,
                            destination: FuelDeviationAlertsView()
                        )
                        
                        reportCard(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Historical Charts",
                            subtitle: "Vehicle trends with anomaly spike annotations",
                            color: FMSTheme.amber,
                            destination: HistoricalVehicleChartsView()
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
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
