import SwiftUI

/// User Story 3: Historical Reports view with date-range filter, trip list, CSV export, and pull-to-refresh.
public struct HistoricalReportsView: View {
    @State private var viewModel = HistoricalReportsViewModel()

    public init() {}

    public var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading reports…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                errorState(error)
            } else if viewModel.reports.isEmpty {
                ContentUnavailableView(
                    "No Trip Reports",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("No trips found for the selected date range.")
                )
            } else {
                contentView
            }
        }
        .navigationTitle("Historical Reports")
        .navigationBarTitleDisplayMode(.inline)
        .background(FMSTheme.backgroundPrimary)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !viewModel.reports.isEmpty {
                    ShareLink(
                        item: viewModel.generateCSV(),
                        subject: Text("Fleet Trip Report"),
                        message: Text("Exported trip data")
                    ) {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .task { await viewModel.fetchReports() }
    }

    // MARK: - Content

    private var contentView: some View {
        List {
            // Date range pickers
            Section {
                DatePicker("From", selection: $viewModel.startDate, displayedComponents: .date)
                DatePicker("To", selection: $viewModel.endDate, displayedComponents: .date)

                Button("Apply Filter") {
                    Task { await viewModel.fetchReports() }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FMSTheme.amber)
            } header: {
                Text("Date Range")
            }

            // Trip results
            Section {
                ForEach(viewModel.reports) { report in
                    tripRow(report)
                }
            } header: {
                Text("\(viewModel.reports.count) Trips")
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await viewModel.fetchReports()
        }
    }

    // MARK: - Trip Row

    private func tripRow(_ report: HistoricalTripReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(formattedDate(report.startTime))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FMSTheme.textPrimary)
                Spacer()
                Text(report.plateNumber)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(FMSTheme.amber)
            }

            HStack {
                Label(report.driverName, systemImage: "person.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(FMSTheme.textSecondary)

                Spacer()

                if let km = report.distanceKm {
                    Label(String(format: "%.1f km", km), systemImage: "road.lanes")
                        .font(.system(size: 12))
                        .foregroundStyle(FMSTheme.textSecondary)
                }

                if let fuel = report.fuelUsedLiters {
                    Label(String(format: "%.1f L", fuel), systemImage: "fuelpump.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(FMSTheme.textSecondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let d = date else { return "—" }
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        return fmt.string(from: d)
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
            Button("Retry") { Task { await viewModel.fetchReports() } }
                .buttonStyle(.borderedProminent)
                .tint(FMSTheme.amber)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
