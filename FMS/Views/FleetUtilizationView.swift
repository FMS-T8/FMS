import SwiftUI

/// User Story 4: Fleet Utilization Report with summary gauge and vehicle list.
public struct FleetUtilizationView: View {
    @State private var viewModel = FleetUtilizationViewModel()

    public init() {}

    public var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading utilization data…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                errorState(error)
            } else if viewModel.vehicles.isEmpty {
                ContentUnavailableView(
                    "No Utilization Data",
                    systemImage: "gauge.with.dots.needle.0percent",
                    description: Text("Fleet utilization data will appear here once vehicles are active.")
                )
            } else {
                contentView
            }
        }
        .navigationTitle("Fleet Utilization")
        .navigationBarTitleDisplayMode(.inline)
        .background(FMSTheme.backgroundPrimary)
        .task { await viewModel.fetchUtilization() }
    }

    // MARK: - Content

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary gauge card
                summaryCard
                    .padding(.horizontal, 20)

                // Low utilization filter toggle
                HStack {
                    Text("Show low utilization only")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(FMSTheme.textPrimary)
                    Spacer()
                    Toggle("", isOn: $viewModel.showLowOnly)
                        .tint(FMSTheme.amber)
                        .labelsHidden()
                }
                .padding(.horizontal, 20)

                // Vehicle list
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.filteredVehicles) { vehicle in
                        UtilizationRow(vehicle: vehicle)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .padding(.top, 16)
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        let avg = viewModel.averageUtilization
        let avgColor: Color = {
            if avg >= 70 { return FMSTheme.alertGreen }
            else if avg >= 40 { return FMSTheme.alertOrange }
            else { return FMSTheme.alertRed }
        }()

        return VStack(spacing: 12) {
            Text("Fleet Average")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(FMSTheme.textSecondary)

            Gauge(value: min(avg, 100), in: 0...100) {
                EmptyView()
            } currentValueLabel: {
                Text(String(format: "%.0f%%", avg))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(avgColor)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(avgColor)
            .scaleEffect(1.6)
            .frame(height: 90)

            Text("\(viewModel.vehicles.count) vehicles tracked")
                .font(.system(size: 12))
                .foregroundStyle(FMSTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(FMSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Error

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(FMSTheme.alertRed)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(FMSTheme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await viewModel.fetchUtilization() } }
                .buttonStyle(.borderedProminent)
                .tint(FMSTheme.amber)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
