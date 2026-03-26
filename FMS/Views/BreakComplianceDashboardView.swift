import SwiftUI

@MainActor
public struct BreakComplianceDashboardView: View {
  @State private var viewModel = BreakComplianceViewModel()

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        headerSection
        summarySection
        driverListSection
      }
      .padding(.horizontal, 20)
      .padding(.top, 16)
      .padding(.bottom, 32)
    }
    .background(FMSTheme.backgroundPrimary)
    .navigationTitle("Break Compliance")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(.hidden, for: .tabBar)
    .refreshable {
      await viewModel.refresh()
    }
    .overlay {
      if viewModel.isLoading && viewModel.records.isEmpty {
        ProgressView("Loading compliance data...")
          .tint(FMSTheme.amber)
      }
    }
    .task {
      await viewModel.refresh()
    }
    .alert(
      "Failed to load break compliance",
      isPresented: Binding(
        get: { viewModel.errorMessage != nil },
        set: { if !$0 { viewModel.errorMessage = nil } }
      )
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(viewModel.errorMessage ?? "")
    }
  }

  private var headerSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Break Compliance")
        .font(.system(size: 26, weight: .bold))
        .foregroundStyle(FMSTheme.textPrimary)

      Text("Ensure drivers take mandated rest periods during active shifts.")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(FMSTheme.textSecondary)

      Text(
        "Policy: Gentle alert at 2h, warning at 3.5h, critical at 4.5h."
      )
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(FMSTheme.textTertiary)
    }
  }


  private var summarySection: some View {
    VStack(spacing: 12) {
      HStack(spacing: 12) {
        summaryCard(
          title: "Compliant",
          value: "\(viewModel.compliantDriversCount)",
          subtitle: "On schedule",
          color: FMSTheme.alertGreen
        )
        summaryCard(
          title: "Due Soon",
          value: "\(viewModel.dueSoonDriversCount)",
          subtitle: "Next 30m",
          color: FMSTheme.alertOrange
        )
      }

      HStack(spacing: 12) {
        summaryCard(
          title: "Overdue",
          value: "\(viewModel.overdueDriversCount)",
          subtitle: "Needs break",
          color: FMSTheme.alertRed
        )
        summaryCard(
          title: "On Break",
          value: "\(viewModel.onBreakDriversCount)",
          subtitle: "Active rests",
          color: FMSTheme.amber
        )
      }
    }
  }

  private func summaryCard(
    title: String,
    value: String,
    subtitle: String,
    color: Color
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title.uppercased())
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(FMSTheme.textTertiary)

      Text(value)
        .font(.system(size: 26, weight: .bold))
        .foregroundStyle(FMSTheme.textPrimary)

      Text(subtitle)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(color)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(FMSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .stroke(color.opacity(0.2), lineWidth: 1)
    )
  }

  private var driverListSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Active Drivers")
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(FMSTheme.textPrimary)

        Spacer()

        Text("\(viewModel.activeDriversCount) on shift")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(FMSTheme.textSecondary)
      }

      if viewModel.records.isEmpty && !viewModel.isLoading {
        ContentUnavailableView(
          "No Active Shifts",
          systemImage: "clock.badge.xmark",
          description: Text("Drivers will appear here once shifts start.")
        )
      } else {
        ForEach(viewModel.records) { record in
          BreakComplianceRow(record: record, rule: viewModel.rule)
        }
      }
    }
  }

  private func formatHours(_ value: Double) -> String {
    if value.rounded() == value {
      return "\(Int(value))h"
    }
    return String(format: "%.1fh", value)
  }


}

private struct BreakComplianceRow: View {
  let record: BreakComplianceViewModel.BreakComplianceDriver
  let rule: BreakComplianceViewModel.BreakComplianceRule

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text(record.name)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(FMSTheme.textPrimary)

          Text(record.employeeId)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(FMSTheme.textSecondary)
        }

        Spacer()

        statusBadge
      }

      Text(record.vehicleLabel)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(FMSTheme.textSecondary)

      HStack(spacing: 8) {
        metricPill(
          label: "Compliant",
          value: "\(record.compliantBreaks)/\(record.requiredBreaks)",
          color: FMSTheme.alertGreen
        )

        if record.missedBreaks > 0 {
          metricPill(
            label: "Missed",
            value: "\(record.missedBreaks)",
            color: FMSTheme.alertRed
          )
        }

        if record.isOnBreak {
          metricPill(
            label: "On Break",
            value: "Active",
            color: FMSTheme.amber
          )
        }
      }

      HStack {
        Text(lastBreakLabel)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(FMSTheme.textSecondary)

        Spacer()

        Text(dueLabel)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(statusColor)
      }

      complianceBar
    }
    .padding(14)
    .background(FMSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .stroke(statusColor.opacity(0.18), lineWidth: 1)
    )
  }

  private var statusBadge: some View {
    Text(statusText)
      .font(.system(size: 11, weight: .bold))
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(statusColor.opacity(0.15), in: Capsule())
      .foregroundStyle(statusColor)
  }

  private var statusText: String {
    switch record.status {
    case .compliant: return "COMPLIANT"
    case .dueSoon: return "DUE SOON"
    case .overdue: return "OVERDUE"
    case .offDuty: return "OFF DUTY"
    }
  }

  private var statusColor: Color {
    switch record.status {
    case .compliant: return FMSTheme.alertGreen
    case .dueSoon: return FMSTheme.alertOrange
    case .overdue: return FMSTheme.alertRed
    case .offDuty: return FMSTheme.textTertiary
    }
  }

  private var lastBreakLabel: String {
    guard let last = record.lastCompliantBreak else { return "Last break: —" }
    return "Last break: \(last.formatted(date: .abbreviated, time: .shortened))"
  }

  private var dueLabel: String {
    guard record.status != .offDuty else { return "No active shift" }
    guard let due = record.dueInMinutes else { return "—" }
    if due <= 0 {
      return "Overdue by \(formatMinutes(abs(due)))"
    }
    if let minutesSince = record.minutesSinceLastBreak,
       Double(minutesSince) >= rule.gentleHours * 60 {
      return "Gentle reminder • Due in \(formatMinutes(due))"
    }
    return "Due in \(formatMinutes(due))"
  }

  private var complianceBar: some View {
    GeometryReader { geo in
      let width = max(0, min(1, record.complianceScore)) * geo.size.width
      ZStack(alignment: .leading) {
        Capsule()
          .fill(FMSTheme.borderLight.opacity(0.4))
          .frame(height: 6)
        Capsule()
          .fill(statusColor)
          .frame(width: width, height: 6)
      }
    }
    .frame(height: 6)
  }

  private func metricPill(label: String, value: String, color: Color) -> some View {
    HStack(spacing: 4) {
      Text(label)
        .font(.system(size: 10, weight: .bold))
      Text(value)
        .font(.system(size: 11, weight: .bold))
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(color.opacity(0.12), in: Capsule())
    .foregroundStyle(color)
  }

  private func formatMinutes(_ value: Int) -> String {
    if value < 60 { return "\(value)m" }
    let hours = value / 60
    let mins = value % 60
    return "\(hours)h \(mins)m"
  }
}
