import SwiftUI

// MARK: - DriversView

public struct DriversView: View {

  @State private var vm = DriversViewModel(dataSource: SupabaseDriversDataSource())
  @State private var showingAddDriver = false

  public init() {}

  public var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(spacing: 0) {
          // Dense header matching the dashboard style
          DriversSummaryHeader(vm: vm)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 12)

          // Picker
          Picker("", selection: $vm.selectedTab) {
            ForEach(DriversTab.allCases, id: \.self) { tab in
              Text(tab.rawValue).tag(tab)
            }
          }
          .pickerStyle(.segmented)
          .padding(.horizontal, 16)
          .padding(.bottom, 12)

          // Tab content
          switch vm.selectedTab {
          case .directory:
            DirectoryTabContent(vm: vm)
          case .shifts:
            ShiftsTabContent(vm: vm)
          }
        }
      }
      .scrollDismissesKeyboard(.interactively)
      .background(Color(.systemGroupedBackground).ignoresSafeArea())
      .overlay {
          if vm.isLoading && vm.drivers.isEmpty {
              ProgressView("Loading workforce...")
                  .tint(FMSTheme.amber)
          }
      }
      .refreshable {
          await vm.fetchData()
      }
      .task {
          await vm.fetchData()
      }
      .alert(
        "Failed to load drivers",
        isPresented: Binding(
          get: { vm.errorMessage != nil },
          set: { if !$0 { vm.errorMessage = nil } }
        )
      ) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(vm.errorMessage ?? "")
      }
      .navigationTitle("")
      .navigationBarTitleDisplayMode(.inline)
      .searchable(text: $vm.searchText, prompt: "Search driver name or ID")
      .toolbar { toolbarContent }
      .sheet(isPresented: $showingAddDriver) {
        AddDriverView(onDriverAdded: {
            Task { await vm.fetchData() }
        })
          .presentationDetents([.large])
      }
    }
  }

  // MARK: Toolbar

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    ToolbarItem(placement: .navigationBarTrailing) {
      Button {
        showingAddDriver = true
      } label: {
        Image(systemName: "person.badge.plus")
          .fontWeight(.medium)
      }
    }
    if vm.selectedTab == .shifts {
      ToolbarItem(placement: .navigationBarTrailing) {
        NavigationLink(destination: ShiftAssignmentView()) {
          Image(systemName: "calendar.badge.plus")
            .fontWeight(.medium)
        }
      }
    }
  }
}

// MARK: - Drivers Summary Header

/// Dense amber card matching the dashboard's fleet-status hero card.
private struct DriversSummaryHeader: View {

  let vm: DriversViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Title row
      HStack(alignment: .firstTextBaseline) {
        Text("Drivers")
          .font(.largeTitle.bold())
          .foregroundStyle(Color(.label))
        Spacer()
        Text("\(vm.totalCount) Total")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Color(.secondaryLabel))
      }

      // Amber summary card
      summaryCard
    }
  }

  private var summaryCard: some View {
    ZStack(alignment: .bottomTrailing) {
      // Background
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(
          LinearGradient(
            colors: [
              FMSTheme.amber,
              FMSTheme.amber.opacity(0.82),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )

      // Ghost icon
      Image(systemName: "person.2.fill")
        .font(.system(size: 90))
        .foregroundStyle(Color(.systemBackground).opacity(0.09))
        .offset(x: 12, y: 18)

      // Content
      HStack(alignment: .top, spacing: 0) {
        VStack(alignment: .leading, spacing: 6) {
          Text("WORKFORCE")
            .font(.caption.weight(.bold))
            .foregroundStyle(Color(.systemBackground).opacity(0.7))

          Text("\(vm.onDutyCount) Active")
            .font(.system(size: 34, weight: .heavy, design: .rounded))
            .foregroundStyle(Color(.systemBackground))

          Text("Drivers on duty right now")
            .font(.subheadline)
            .foregroundStyle(Color(.systemBackground).opacity(0.75))

          // Stat pills
          HStack(spacing: 8) {
            StatPill(
              label: "On Trip", count: vm.onTripCount,
              icon: "arrow.triangle.turn.up.right.circle.fill")
            StatPill(
              label: "Available", count: vm.driverCount(for: .available),
              icon: "checkmark.circle.fill")
            StatPill(label: "Off Duty", count: vm.offDutyCount, icon: "moon.fill")
          }
          .padding(.top, 4)
        }
        .padding(20)

        Spacer()
      }
    }
    .frame(maxWidth: .infinity)
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
  }
}

// MARK: - Stat Pill

private struct StatPill: View {
  let label: String
  let count: Int
  let icon: String

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: icon)
        .font(.caption2)
      Text("\(count) \(label)")
        .font(.caption.weight(.semibold))
    }
    .foregroundStyle(Color(.systemBackground).opacity(0.85))
    .padding(.horizontal, 10)
    .padding(.vertical, 5)
    .background(Color(.systemBackground).opacity(0.18))
    .clipShape(Capsule())
  }
}

// MARK: - Directory Content

private struct DirectoryTabContent: View {
  @Bindable var vm: DriversViewModel

  var body: some View {
    LazyVStack(spacing: 0) {
      filterChips
        .padding(.horizontal, 16)
        .padding(.bottom, 10)

      if vm.filteredDrivers.isEmpty {
        EmptyStateView(icon: "person.slash", message: "No drivers found")
          .padding(.top, 60)
      } else {
        ForEach(vm.filteredDrivers) { driver in
          NavigationLink(destination: DriverDetailView(driver: driver)) {
            DriverCardView(driver: driver, onCall: nil)
              .padding(.horizontal, 16)
              .padding(.vertical, 5)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private var filterChips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        FilterChip(
          title: "All",
          count: vm.driverCount(for: nil),
          isSelected: vm.selectedFilter == nil
        ) { vm.selectedFilter = nil }

        ForEach(DriverAvailabilityStatus.allCases, id: \.self) { status in
          FilterChip(
            title: status.displayLabel,
            count: vm.driverCount(for: status),
            isSelected: vm.selectedFilter == status
          ) { vm.selectedFilter = vm.selectedFilter == status ? nil : status }
        }
      }
      .padding(.vertical, 2)
    }
  }
}

// MARK: - Shifts Content

private struct ShiftsTabContent: View {
  @Bindable var vm: DriversViewModel

  var body: some View {
    LazyVStack(spacing: 0) {
      dayStrip
        .padding(.horizontal, 16)
        .padding(.bottom, 10)

      if vm.shiftsForDate.isEmpty {
        EmptyStateView(icon: "calendar.badge.minus", message: "No shifts scheduled")
          .padding(.top, 60)
      } else {
        ForEach(vm.shiftsForDate) { shift in
          NavigationLink(destination: DriverShiftDetailView(shift: shift)) {
            DriverShiftCardView(shift: shift, onTrack: nil)
              .padding(.horizontal, 16)
              .padding(.vertical, 5)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .padding(.bottom, 32)
  }

  private var dayStrip: some View {
    HStack(spacing: 6) {
      ForEach(vm.weekDays, id: \.self) { day in
        DayCell(
          date: day,
          isSelected: Calendar.current.isDate(day, inSameDayAs: vm.selectedDate)
        ) { vm.selectedDate = day }
      }
    }
  }
}

// MARK: - Filter Chip

private struct FilterChip: View {
  let title: String
  let count: Int
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 5) {
        Text(title)
          .font(.subheadline.weight(isSelected ? .semibold : .regular))
        Text("\(count)")
          .font(.caption.weight(.bold))
          .padding(.horizontal, 5)
          .padding(.vertical, 2)
          .background(
            isSelected
              ? Color.white.opacity(0.35)
              : Color(.tertiarySystemFill)
          )
          .clipShape(Capsule())
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .foregroundStyle(isSelected ? .white : Color(.label))
      .background {
        if isSelected {
          Capsule().fill(FMSTheme.amber)
        } else {
          Capsule().fill(Color(.secondarySystemGroupedBackground))
        }
      }
      .overlay {
        if !isSelected {
          Capsule().strokeBorder(Color(.separator), lineWidth: 0.5)
        }
      }
    }
    .animation(.easeInOut(duration: 0.18), value: isSelected)
  }
}

// MARK: - Day Cell

private struct DayCell: View {
  let date: Date
  let isSelected: Bool
  let action: () -> Void
  private static let weekdayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "EEE"
    return f
  }()

  private static let dayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "d"
    return f
  }()
  var body: some View {
    Button(action: action) {
      VStack(spacing: 3) {
        Text(abbrev)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(isSelected ? .white : Color(.secondaryLabel))
        Text(number)
          .font(.system(size: 16, weight: isSelected ? .bold : .regular, design: .rounded))
          .foregroundStyle(isSelected ? .white : Color(.label))
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 8)
      .background {
        if isSelected {
          RoundedRectangle(cornerRadius: 10, style: .continuous).fill(FMSTheme.amber)
        }
      }
    }
    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isSelected)
  }

  private var abbrev: String {
    Self.weekdayFormatter.string(from: date).uppercased()
  }

  private var number: String {
    Self.dayFormatter.string(from: date)
  }
}

// MARK: - Empty State

private struct EmptyStateView: View {
  let icon: String
  let message: String

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: icon)
        .font(.system(size: 44))
        .foregroundStyle(Color(.tertiaryLabel))
      Text(message)
        .font(.body)
        .foregroundStyle(Color(.secondaryLabel))
    }
    .frame(maxWidth: .infinity)
  }
}

#Preview { DriversView() }
