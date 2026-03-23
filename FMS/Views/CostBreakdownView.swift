import Charts
import SwiftUI

/// User Story 1: Monthly Cost Breakdown view with stacked bar chart, line overlay, and variance badges.
public struct CostBreakdownView: View {
  @State private var viewModel = CostBreakdownViewModel()

  public init() {}

  public var body: some View {
    Group {
      if viewModel.isLoading {
        ProgressView("Loading costs…")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let error = viewModel.errorMessage {
        errorState(error)
      } else if viewModel.filteredSummaries.isEmpty {
        ContentUnavailableView(
          "No Cost Data",
          systemImage: "chart.bar.xaxis",
          description: Text("Cost breakdown data will appear here once available.")
        )
      } else {
        contentView
      }
    }
    .navigationTitle("Cost Breakdown")
    .navigationBarTitleDisplayMode(.inline)
    .background(FMSTheme.backgroundPrimary)
    .task { await viewModel.fetchCosts() }
  }

  // MARK: - Content

  private var contentView: some View {
    ScrollView {
      VStack(spacing: 20) {
        // Month range picker
        Picker("Range", selection: $viewModel.selectedRange) {
          ForEach(CostBreakdownViewModel.MonthRange.allCases) { range in
            Text(range.label).tag(range)
          }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)

        // Stacked bar chart + line overlay
        chartSection
          .padding(.horizontal, 20)

        // Variance badges
        varianceSection
          .padding(.horizontal, 20)

        // Legend
        legendSection
          .padding(.horizontal, 20)
      }
      .padding(.top, 16)
      .padding(.bottom, 32)
    }
  }

  // MARK: - Chart

  private var chartSection: some View {
    let items = viewModel.filteredSummaries

    return Chart {
      ForEach(items) { item in
        BarMark(
          x: .value("Month", item.displayMonth),
          y: .value("Cost", item.fuelCost)
        )
        .foregroundStyle(by: .value("Type", "Fuel"))

        BarMark(
          x: .value("Month", item.displayMonth),
          y: .value("Cost", item.maintenanceCost)
        )
        .foregroundStyle(by: .value("Type", "Maintenance"))
      }

      // Total cost line overlay
      ForEach(items) { item in
        LineMark(
          x: .value("Month", item.displayMonth),
          y: .value("Total", item.totalCost)
        )
        .foregroundStyle(FMSTheme.amber)
        .lineStyle(StrokeStyle(lineWidth: 2.5))
        .symbol {
          Circle()
            .fill(FMSTheme.amber)
            .frame(width: 7, height: 7)
        }
      }
    }
    .chartForegroundStyleScale([
      "Fuel": FMSTheme.alertOrange,
      "Maintenance": FMSTheme.alertRed,
    ])
    .chartYAxis {
      AxisMarks(position: .leading) { value in
        AxisValueLabel {
          if let v = value.as(Double.self) {
            Text("₹\(v, specifier: "%.0f")")
              .font(.system(size: 10))
              .foregroundStyle(FMSTheme.textSecondary)
          }
        }
        AxisGridLine()
      }
    }
    .chartXAxis {
      AxisMarks { value in
        AxisValueLabel()
          .font(.system(size: 10))
          .foregroundStyle(FMSTheme.textSecondary)
      }
    }
    .frame(height: 260)
    .padding(16)
    .background(FMSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
  }

  // MARK: - Variance Badges Row

  private var varianceSection: some View {
    let items = viewModel.filteredSummaries
    let variances = viewModel.variancePercentages

    return VStack(alignment: .leading, spacing: 8) {
      Text("Month-over-Month Variance")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(FMSTheme.textPrimary)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(Array(zip(items.indices, items)), id: \.1.id) { idx, item in
            let safeVariance = variances.indices.contains(idx) ? variances[idx] : nil
            VStack(spacing: 4) {
              Text(item.displayMonth)
                .font(.system(size: 11))
                .foregroundStyle(FMSTheme.textSecondary)
              VarianceBadge(percent: safeVariance)
            }
          }
        }
      }
    }
    .padding(14)
    .background(FMSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
  }

  // MARK: - Legend

  private var legendSection: some View {
    HStack(spacing: 20) {
      legendItem(color: FMSTheme.alertOrange, label: "Fuel Cost")
      legendItem(color: FMSTheme.alertRed, label: "Maintenance")
      legendItem(color: FMSTheme.amber, label: "Total Trend")
    }
    .padding(12)
    .background(FMSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
  }

  private func legendItem(color: Color, label: String) -> some View {
    HStack(spacing: 6) {
      Circle().fill(color).frame(width: 8, height: 8)
      Text(label)
        .font(.system(size: 12))
        .foregroundStyle(FMSTheme.textSecondary)
    }
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
      Button("Retry") { Task { await viewModel.fetchCosts() } }
        .buttonStyle(.borderedProminent)
        .tint(FMSTheme.amber)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
