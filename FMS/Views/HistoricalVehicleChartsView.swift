import Charts
import SwiftUI

public struct HistoricalVehicleChartsView: View {
    @State private var viewModel = HistoricalVehicleChartsViewModel()
    @State private var showCustomRangeSheet = false

    public init() {}

    public var body: some View {
        Group {
            if viewModel.isLoading && viewModel.points.isEmpty {
                ProgressView("Loading vehicle trends...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                errorState(error)
            } else if viewModel.points.isEmpty {
                ContentUnavailableView(
                    "No Trend Data",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("No data available for the selected vehicle and range.")
                )
            } else {
                content
            }
        }
        .navigationTitle("Historical Charts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(isPresented: $showCustomRangeSheet) {
            NavigationStack {
                Form {
                    DatePicker("From", selection: $viewModel.customStartDate, displayedComponents: .date)
                    DatePicker("To", selection: $viewModel.customEndDate, in: viewModel.customStartDate..., displayedComponents: .date)
                }
                .navigationTitle("Custom Range")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { showCustomRangeSheet = false }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Apply") {
                            showCustomRangeSheet = false
                            Task { await viewModel.fetchSeries() }
                        }
                        .fontWeight(.bold)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .task { await viewModel.loadInitialData() }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                selectors

                Text(viewModel.dateRangeLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FMSTheme.textSecondary)

                chartCard

                Text("Anomalies detected: \(viewModel.anomalyCount)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(viewModel.anomalyCount > 0 ? FMSTheme.alertRed : FMSTheme.alertGreen)
            }
            .padding(16)
        }
    }

    private var selectors: some View {
        VStack(spacing: 10) {
            Picker("Vehicle", selection: Binding(
                get: { viewModel.selectedVehicleId ?? "" },
                set: { newValue in
                    viewModel.selectedVehicleId = newValue
                    Task { await viewModel.fetchSeries() }
                }
            )) {
                ForEach(viewModel.vehicles) { vehicle in
                    Text(vehicle.plateNumber).tag(vehicle.id)
                }
            }
            .pickerStyle(.menu)

            Picker("Metric", selection: $viewModel.selectedMetric) {
                ForEach(HistoricalVehicleChartsViewModel.Metric.allCases) { metric in
                    Text(metric.rawValue).tag(metric)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.selectedMetric) { _, _ in
                Task { await viewModel.fetchSeries() }
            }

            Picker("Date Range", selection: $viewModel.selectedWindow) {
                ForEach(HistoricalVehicleChartsViewModel.DateWindow.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.selectedWindow) { _, newValue in
                if newValue == .custom {
                    showCustomRangeSheet = true
                } else {
                    viewModel.applyDateWindow()
                    Task { await viewModel.fetchSeries() }
                }
            }
        }
        .padding(12)
        .background(FMSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    private var chartCard: some View {
        Chart {
            ForEach(viewModel.points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(FMSTheme.amber)
                .lineStyle(StrokeStyle(lineWidth: 2.2))

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(point.isAnomaly ? FMSTheme.alertRed : FMSTheme.alertOrange)
                .symbolSize(point.isAnomaly ? 80 : 28)

                if point.isAnomaly {
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .annotation(position: .top) {
                        Text("Anomaly")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(FMSTheme.alertRed)
                    }
                    .foregroundStyle(FMSTheme.alertRed)
                    .symbol(.triangle)
                    .symbolSize(70)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 280)
        .padding(12)
        .background(FMSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(FMSTheme.alertRed)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(FMSTheme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await viewModel.fetchSeries() } }
                .buttonStyle(.borderedProminent)
                .tint(FMSTheme.amber)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
