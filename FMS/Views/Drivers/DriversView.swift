import SwiftUI

// MARK: - DriversView

/// Top-level view for the Drivers module.
///
/// Uses:
/// - `NavigationStack` for iOS native navigation
/// - `Picker` with `.segmentedPickerStyle()` to switch Directory/Shifts
/// - `.searchable()` for the search bar
/// - `Toolbar` with add-driver button
/// - `NavigationLink` on each card to push detail screens
///
/// Owns a single `DriversViewModel` via `@State`.
public struct DriversView: View {

    @State private var vm = DriversViewModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented control
                Picker("Tab", selection: $vm.selectedTab) {
                    ForEach(DriversTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Divider()

                // Content
                switch vm.selectedTab {
                case .directory:
                    directoryContent
                case .shifts:
                    shiftsContent
                }
            }
            .background(FMSTheme.backgroundPrimary)
            .navigationTitle("Drivers")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $vm.searchText,
                prompt: "Search driver name or ID"
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // TODO: Present add-driver sheet
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(FMSTheme.textPrimary)
                    }
                }
            }
        }
    }

    // MARK: - Directory Content

    private var directoryContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Filter chips
                filterChips

                if vm.filteredDrivers.isEmpty {
                    emptyState(icon: "person.slash.fill", message: "No drivers found")
                } else {
                    ForEach(vm.filteredDrivers) { driver in
                        NavigationLink(destination: DriverDetailView(driver: driver)) {
                            DriverCardView(driver: driver)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Shifts Content

    private var shiftsContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Day strip
                dayStrip
                    .padding(.bottom, 4)

                if vm.shiftsForDate.isEmpty {
                    emptyState(icon: "calendar.badge.minus", message: "No shifts scheduled")
                } else {
                    ForEach(vm.shiftsForDate) { shift in
                        NavigationLink(destination: DriverShiftDetailView(shift: shift)) {
                            DriverShiftCardView(shift: shift)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ChipButton(title: "All", isSelected: vm.selectedFilter == nil) {
                    vm.selectedFilter = nil
                }
                ForEach(DriverAvailabilityStatus.allCases, id: \.self) { status in
                    ChipButton(
                        title: status.displayLabel,
                        isSelected: vm.selectedFilter == status
                    ) {
                        vm.selectedFilter = status
                    }
                }
            }
        }
    }

    // MARK: - Day Strip

    private var dayStrip: some View {
        HStack(spacing: 6) {
            ForEach(vm.weekDays, id: \.self) { day in
                DayButton(
                    date: day,
                    isSelected: Calendar.current.isDate(day, inSameDayAs: vm.selectedDate)
                ) {
                    vm.selectedDate = day
                }
            }
        }
    }

    // MARK: - Empty State

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(FMSTheme.textTertiary)
            Text(message)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(FMSTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Chip Button

private struct ChipButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? FMSTheme.amber : FMSTheme.cardBackground)
                .foregroundStyle(isSelected ? FMSTheme.obsidian : FMSTheme.textSecondary)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        isSelected ? Color.clear : FMSTheme.borderLight,
                        lineWidth: 1
                    )
                )
        }
    }
}

// MARK: - Day Button

private struct DayButton: View {
    let date: Date
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(dayAbbrev)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? .white : FMSTheme.textSecondary)
                Text(dayNumber)
                    .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? .white : FMSTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? FMSTheme.amber : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var dayAbbrev: String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }

    private var dayNumber: String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    DriversView()
}
