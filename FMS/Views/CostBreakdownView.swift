import Charts
import SwiftUI

/// Consolidated spend dashboard for fuel, maintenance, and toll costs.
public struct CostBreakdownView: View {
  @State private var viewModel = CostBreakdownViewModel()
  @State private var showCustomRangeSheet = false

  public init() {}

  public var body: some View {
    Group {
      if viewModel.isLoading {
        ProgressView("Loading costs…")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let error = viewModel.errorMessage {
        errorState(error)
      } else if viewModel.grandTotal <= 0 {
        ContentUnavailableView(
          "No Cost Data",
          systemImage: "chart.bar.xaxis",
          description: Text("Cost breakdown data will appear here once available.")
        )
      } else {
        contentView
      }
    }
    .navigationTitle("Spend Dashboard")
    .navigationBarTitleDisplayMode(.inline)
    .background(FMSTheme.backgroundPrimary)
    .sheet(isPresented: $showCustomRangeSheet) {
      NavigationStack {
        Form {
          DatePicker("From", selection: $viewModel.customStartDate, displayedComponents: .date)
          DatePicker(
            "To", selection: $viewModel.customEndDate, in: viewModel.customStartDate...,
            displayedComponents: .date)
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
              Task { await viewModel.fetchCosts() }
            }
            .fontWeight(.bold)
          }
        }
      }
      .presentationDetents([.medium])
    }
    .task { await viewModel.fetchCosts() }
  }

  // MARK: - Content

  private var contentView: some View {
    ScrollView {
      VStack(spacing: 20) {
        Picker("Range", selection: $viewModel.selectedRange) {
          ForEach(CostBreakdownViewModel.DateRange.allCases) { range in
            Text(range.rawValue).tag(range)
          }
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.selectedRange) { _, newValue in
          if newValue == .custom {
            showCustomRangeSheet = true
          } else {
            Task { await viewModel.fetchCosts() }
          }
        }
        .padding(.horizontal, 20)

        Text(viewModel.dateRangeLabel)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(FMSTheme.textSecondary)

        summaryCards
          .padding(.horizontal, 20)

        chartSection
          .padding(.horizontal, 20)
      }
      .padding(.top, 16)
      .padding(.bottom, 32)
    }
  }

  // MARK: - Summary Cards

  private var summaryCards: some View {
    VStack(spacing: 12) {
      HStack(spacing: 12) {
        spendCard(title: "Fuel", value: viewModel.fuelSpend, color: FMSTheme.alertOrange)
        spendCard(title: "Maintenance", value: viewModel.maintenanceSpend, color: FMSTheme.alertRed)
      }
      HStack(spacing: 12) {
        spendCard(title: "Tolls", value: viewModel.tollSpend, color: FMSTheme.alertGreen)
        spendCard(title: "Grand Total", value: viewModel.grandTotal, color: FMSTheme.amber)
      }
    }
  }

  private func spendCard(title: String, value: Double, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(FMSTheme.textSecondary)
      Text(String(format: "₹%.0f", value))
        .font(.system(size: 18, weight: .bold, design: .rounded))
        .foregroundStyle(color)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(FMSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
  }

  // MARK: - Chart

  private var chartSection: some View {
    let items = viewModel.spendBreakdown.filter { $0.amount > 0 }

    return Chart {
      ForEach(items) { item in
        BarMark(
          x: .value("Category", item.label),
          y: .value("Amount", item.amount)
        )
        .foregroundStyle(by: .value("Category", item.label))
        .annotation(position: .top) {
          Text("₹\(Int(item.amount))")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(FMSTheme.textSecondary)
        }
      }
    }
    .chartForegroundStyleScale([
      "Fuel": FMSTheme.alertOrange,
      "Maintenance": FMSTheme.alertRed,
      "Tolls": FMSTheme.alertGreen,
    ])
    .chartLegend(position: .bottom)
    .frame(height: 260)
    .padding(16)
    .background(FMSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
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
