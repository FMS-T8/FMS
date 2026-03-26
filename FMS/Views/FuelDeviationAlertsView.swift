import SwiftUI

public struct FuelDeviationAlertsView: View {
  @State private var viewModel = FuelDeviationAlertsViewModel()

  public init() {}

  public var body: some View {
    Group {
      if viewModel.isLoading && viewModel.alerts.isEmpty {
        ProgressView("Checking fuel deviations...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let error = viewModel.errorMessage {
        errorState(error)
      } else if viewModel.alerts.isEmpty {
        ContentUnavailableView(
          "No Fuel Deviation Alerts",
          systemImage: "checkmark.shield",
          description: Text("No vehicles exceed the configured deviation threshold.")
        )
      } else {
        content
      }
    }
    .navigationTitle("Fuel Deviation Alerts")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Refresh") {
          Task { await viewModel.runDeviationCheck() }
        }
      }
    }
    .task {
      viewModel.startPolling()
    }
    .onDisappear {
      viewModel.stopPolling()
    }
  }

  private var content: some View {
    List {
      Section {
        HStack {
          Text("Threshold")
            .font(.system(size: 14, weight: .semibold))
          Spacer()
          Text("\(Int(viewModel.thresholdPercent))%")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(FMSTheme.amber)
        }

        Slider(
          value: $viewModel.thresholdPercent,
          in: 5...40,
          step: 1,
          onEditingChanged: { isEditing in
            guard !isEditing else { return }
            Task { await viewModel.runDeviationCheck() }
          }
        )
        .tint(FMSTheme.amber)
      }

      Section("Alerts") {
        ForEach(viewModel.alerts) { alert in
          alertRow(alert)
        }
      }
    }
    .listStyle(.insetGrouped)
  }

  private func alertRow(_ alert: FuelDeviationAlert) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(alert.vehicleLabel)
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(FMSTheme.textPrimary)

        Spacer()

        Text(statusText(alert.status))
          .font(.system(size: 11, weight: .bold))
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(statusColor(alert.status).opacity(0.16), in: Capsule())
          .foregroundStyle(statusColor(alert.status))
      }

      Text(
        String(
          format: "Current %.2f km/L vs baseline %.2f km/L (%+.1f%%)", alert.currentRate,
          alert.baselineRate, alert.deviationPercent)
      )
      .font(.system(size: 12, weight: .medium))
      .foregroundStyle(alert.deviationPercent >= 0 ? FMSTheme.alertGreen : FMSTheme.alertRed)

      Text(alert.timestamp.formatted(date: .abbreviated, time: .shortened))
        .font(.system(size: 11))
        .foregroundStyle(FMSTheme.textSecondary)

      HStack(spacing: 10) {
        Button("Acknowledge") {
          Task {
            await viewModel.updateStatus(vehicleId: alert.vehicleId, status: .acknowledged)
          }
        }
        .buttonStyle(.bordered)
        .tint(FMSTheme.alertOrange)

        Button("Resolve") {
          Task {
            await viewModel.updateStatus(vehicleId: alert.vehicleId, status: .resolved)
          }
        }
        .buttonStyle(.borderedProminent)
        .tint(FMSTheme.alertGreen)
      }
    }
    .padding(.vertical, 6)
  }

  private func statusColor(_ status: FuelDeviationAlertStatus) -> Color {
    switch status {
    case .active:
      return FMSTheme.alertRed
    case .acknowledged:
      return FMSTheme.alertOrange
    case .resolved:
      return FMSTheme.alertGreen
    }
  }

  private func statusText(_ status: FuelDeviationAlertStatus) -> String {
    switch status {
    case .active:
      return "ACTIVE"
    case .acknowledged:
      return "ACKNOWLEDGED"
    case .resolved:
      return "RESOLVED"
    }
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
      Button("Retry") { Task { await viewModel.runDeviationCheck() } }
        .buttonStyle(.borderedProminent)
        .tint(FMSTheme.amber)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
