import SwiftUI

public struct FuelCostReportView: View {
  @State private var viewModel = FuelCostReportViewModel()
  @State private var searchText: String = ""
  @State private var sortColumn: SortColumn?
  @State private var sortDirection: SortDirection = .ascending

  private enum SortDirection {
    case ascending
    case descending
  }

  private enum SortColumn {
    case vehicle
    case litres
    case costPerLiter
    case spend
    case budget
    case variance
  }

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
    .toolbar(.visible, for: .navigationBar)
    .background(FMSTheme.backgroundPrimary)
    .task { await viewModel.fetchReport() }
  }

  private var content: some View {
    ScrollView {
      VStack(spacing: 14) {
        filters
        searchBar
        ScrollView(.horizontal, showsIndicators: true) {
          VStack(spacing: 0) {
            tableHeader
            ForEach(displayedRows) { row in
              reportRow(row)
            }
            totalsRow
          }
          .frame(minWidth: 720, alignment: .leading)
          .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
          .overlay(
            RoundedRectangle(cornerRadius: 14)
              .stroke(FMSTheme.borderLight, lineWidth: 1)
          )
        }
      }
      .padding(16)
    }
    .scrollDismissesKeyboard(.immediately)
  }

  private var filters: some View {
    VStack(spacing: 12) {
      Picker("Vehicle Group", selection: $viewModel.selectedGroup) {
        ForEach(FuelCostReportViewModel.VehicleGroup.allCases) { group in
          Text(group.rawValue)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .tag(group)
        }
      }
      .pickerStyle(.segmented)

      HStack(alignment: .center, spacing: 12) {
        HStack(spacing: 6) {
          Text("From")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(FMSTheme.textSecondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)

          DatePicker("", selection: $viewModel.startDate, displayedComponents: .date)
            .labelsHidden()
            .accessibilityLabel("Start date")
            .datePickerStyle(.compact)
            .tint(FMSTheme.amber)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        HStack(spacing: 6) {
          Text("To")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(FMSTheme.textSecondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)

          DatePicker(
            "", selection: $viewModel.endDate, in: viewModel.startDate...,
            displayedComponents: .date
          )
          .labelsHidden()
          .accessibilityLabel("End date")
          .datePickerStyle(.compact)
          .tint(FMSTheme.amber)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      Button {
        Task { await viewModel.fetchReport() }
      } label: {
        Text("Apply Filters")
          .font(.system(size: 16, weight: .semibold))
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .buttonBorderShape(.roundedRectangle(radius: 12))
      .tint(FMSTheme.amber)
      .foregroundStyle(FMSTheme.obsidian)
    }
    .padding(12)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .stroke(FMSTheme.borderLight, lineWidth: 1)
    )
  }

  private var searchBar: some View {
    HStack(spacing: 10) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(FMSTheme.textSecondary)

      TextField("Search by registration number", text: $searchText)
        .textInputAutocapitalization(.characters)
        .autocorrectionDisabled()
        .foregroundStyle(FMSTheme.textPrimary)

      if !searchText.isEmpty {
        Button {
          searchText = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(FMSTheme.textTertiary)
        }
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(FMSTheme.borderLight, lineWidth: 1)
    )
  }

  private var displayedRows: [FuelCostReportViewModel.Row] {
    let baseRows = viewModel.filteredRows
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let searchedRows =
      query.isEmpty
      ? baseRows
      : baseRows.filter { $0.plateNumber.lowercased().contains(query) }

    guard let sortColumn else { return searchedRows }

    return searchedRows.sorted { lhs, rhs in
      let isAscending = sortDirection == .ascending
      switch sortColumn {
      case .vehicle:
        return isAscending
          ? lhs.plateNumber.localizedCaseInsensitiveCompare(rhs.plateNumber) == .orderedAscending
          : lhs.plateNumber.localizedCaseInsensitiveCompare(rhs.plateNumber) == .orderedDescending
      case .litres:
        return isAscending
          ? lhs.litersConsumed < rhs.litersConsumed : lhs.litersConsumed > rhs.litersConsumed
      case .costPerLiter:
        return isAscending
          ? lhs.costPerLiter < rhs.costPerLiter : lhs.costPerLiter > rhs.costPerLiter
      case .spend:
        return isAscending ? lhs.totalSpend < rhs.totalSpend : lhs.totalSpend > rhs.totalSpend
      case .budget:
        return isAscending
          ? lhs.budgetAllocated < rhs.budgetAllocated : lhs.budgetAllocated > rhs.budgetAllocated
      case .variance:
        return isAscending ? lhs.variance < rhs.variance : lhs.variance > rhs.variance
      }
    }
  }

  private var tableHeader: some View {
    HStack {
      headerCell("Vehicle", column: .vehicle)
      headerCell("Litres", column: .litres)
      headerCell("Cost/L", column: .costPerLiter)
      headerCell("Spend", column: .spend)
      headerCell("Budget", column: .budget)
      headerCell("Variance", column: .variance)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(FMSTheme.pillBackground)
  }

  private func headerCell(_ text: String, column: SortColumn) -> some View {
    Button {
      cycleSort(for: column)
    } label: {
      HStack(spacing: 2) {
        Text(text)
        if sortColumn == column {
          Text(sortDirection == .ascending ? "↑" : "↓")
        }
      }
      .font(.system(size: 11, weight: .bold))
      .foregroundStyle(FMSTheme.textSecondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private func cycleSort(for column: SortColumn) {
    if sortColumn != column {
      sortColumn = column
      sortDirection = .ascending
      return
    }

    if sortDirection == .ascending {
      sortDirection = .descending
    } else {
      sortColumn = nil
      sortDirection = .ascending
    }
  }

  private func reportRow(_ row: FuelCostReportViewModel.Row) -> some View {
    VStack(spacing: 0) {
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
      .padding(.horizontal, 12)
      .padding(.vertical, 11)

      Divider()
        .overlay(FMSTheme.borderLight)
    }
  }

  private var totalsRow: some View {
    let totals = aggregateRows(displayedRows)
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
    .padding(.horizontal, 12)
    .padding(.vertical, 12)
    .background(FMSTheme.amber.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
  }

  private func aggregateRows(_ rows: [FuelCostReportViewModel.Row]) -> FuelCostReportViewModel.Row {
    let liters = rows.reduce(0) { $0 + $1.litersConsumed }
    let spend = rows.reduce(0) { $0 + $1.totalSpend }
    let budget = rows.reduce(0) { $0 + $1.budgetAllocated }
    let costPerLiter = liters > 0 ? spend / liters : 0
    return FuelCostReportViewModel.Row(
      id: "totals",
      plateNumber: "Totals",
      litersConsumed: liters,
      costPerLiter: costPerLiter,
      totalSpend: spend,
      budgetAllocated: budget
    )
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
