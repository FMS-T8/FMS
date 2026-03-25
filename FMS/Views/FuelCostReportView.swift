import SwiftUI

public struct FuelCostReportView: View {
  @State private var viewModel = FuelCostReportViewModel()

  public init() {}

  public var body: some View {
    Group {
      if viewModel.isLoading {
        ProgressView("Loading fuel costs...")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let error = viewModel.errorMessage {
        errorState(error)
      } else {
        content
      }
    }
    .navigationTitle("Fuel Cost Report")
    .navigationBarTitleDisplayMode(.inline)
    .background(FMSTheme.backgroundPrimary)
    .task { await viewModel.fetchReport() }
  }

  private var content: some View {
    ScrollView {
      VStack(spacing: 16) {
        filters
        ScrollView(.horizontal, showsIndicators: true) {
          VStack(spacing: 8) {
            tableHeader
            ForEach(viewModel.filteredRows) { row in
              reportRow(row)
            }
            totalsRow
          }
          .frame(minWidth: 720, alignment: .leading)
        }
      }
      .padding(16)
    }
  }

  private var filters: some View {
    VStack(spacing: 10) {
      Picker("Vehicle Group", selection: $viewModel.selectedGroup) {
        ForEach(FuelCostReportViewModel.VehicleGroup.allCases) { group in
          Text(group.rawValue).tag(group)
        }
      }
      .pickerStyle(.segmented)

      HStack(spacing: 10) {
        DatePicker("From", selection: $viewModel.startDate, displayedComponents: .date)
        DatePicker(
          "To", selection: $viewModel.endDate, in: viewModel.startDate...,
          displayedComponents: .date)
      }

      Button("Apply Filters") {
        Task { await viewModel.fetchReport() }
      }
      .font(.system(size: 14, weight: .bold))
      .foregroundStyle(FMSTheme.amber)
    }
    .padding(12)
    .background(FMSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
  }

  private var tableHeader: some View {
    HStack {
      headerCell("Vehicle")
      headerCell("Litres")
      headerCell("Cost/L")
      headerCell("Spend")
      headerCell("Budget")
      headerCell("Variance")
    }
    .padding(.horizontal, 8)
  }

  private func headerCell(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 11, weight: .bold))
      .foregroundStyle(FMSTheme.textSecondary)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func reportRow(_ row: FuelCostReportViewModel.Row) -> some View {
    HStack {
      cell(row.plateNumber)
      cell(String(format: "%.1f", row.litersConsumed))
      cell(String(format: "₹%.1f", row.costPerLiter))
      cell(String(format: "₹%.0f", row.totalSpend))
      cell(String(format: "₹%.0f", row.budgetAllocated))
      cell(
        String(format: "%@₹%.0f", row.variance >= 0 ? "+" : "-", abs(row.variance)),
        color: row.variance <= 0 ? FMSTheme.alertGreen : FMSTheme.alertRed
      )
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 10)
    .background(FMSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
  }

  private var totalsRow: some View {
    let totals = viewModel.totals
    return HStack {
      cell("Totals", weight: .bold)
      cell(String(format: "%.1f", totals.litersConsumed), weight: .bold)
      cell(String(format: "₹%.1f", totals.costPerLiter), weight: .bold)
      cell(String(format: "₹%.0f", totals.totalSpend), weight: .bold)
      cell(String(format: "₹%.0f", totals.budgetAllocated), weight: .bold)
      cell(
        String(format: "%@₹%.0f", totals.variance >= 0 ? "+" : "-", abs(totals.variance)),
        color: totals.variance <= 0 ? FMSTheme.alertGreen : FMSTheme.alertRed,
        weight: .bold
      )
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 10)
    .background(FMSTheme.amber.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
  }

  private func cell(
    _ text: String, color: Color = FMSTheme.textPrimary, weight: Font.Weight = .semibold
  ) -> some View {
    Text(text)
      .font(.system(size: 11, weight: weight))
      .foregroundStyle(color)
      .frame(maxWidth: .infinity, alignment: .leading)
      .lineLimit(1)
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
      Button("Retry") { Task { await viewModel.fetchReport() } }
        .buttonStyle(.borderedProminent)
        .tint(FMSTheme.amber)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
