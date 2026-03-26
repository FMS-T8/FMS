import SwiftUI

struct DriverTripsTab: View {
    @Bindable var viewModel: DriverDashboardViewModel
    @State private var selectedTrip: Trip?

    var body: some View {
        NavigationStack {
            ZStack {
                FMSTheme.backgroundPrimary.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        headerSection
                        
                        Picker("", selection: $viewModel.selectedSegment) {
                            ForEach(TripSegment.allCases, id: \.self) { segment in
                                Text(segment.rawValue).tag(segment)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        
                        switch viewModel.selectedSegment {
                        case .upcoming:
                            upcomingContent
                        case .history:
                            historyContent
                        }
                    }
                }
            }
            .navigationDestination(item: $selectedTrip) { trip in
                NewTripAssignmentView(trip: trip, viewModel: viewModel)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Trips")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)

            Text("Upcoming schedules and trip history")
                .font(.system(size: 14))
                .foregroundStyle(FMSTheme.textSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Upcoming

    private var upcomingContent: some View {
        LazyVStack(spacing: 10) {
            if viewModel.upcomingTrips.isEmpty {
                emptyState(
                    icon: "calendar.badge.clock",
                    title: "No Upcoming Trips",
                    subtitle: "New trip assignments will appear here"
                )
            } else {
                ForEach(viewModel.upcomingTrips) { trip in
                    Button {
                        selectedTrip = trip
                    } label: {
                        TripHistoryCard(trip: trip)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 32)
    }

    // MARK: - History

    private var historyContent: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(FMSTheme.textTertiary)

                TextField("Search trips...", text: $viewModel.searchText)
                    .font(.system(size: 15))
            }
            .padding(12)
            .background(FMSTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(FMSTheme.borderLight, lineWidth: 1)
            )

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TripFilterOption.allCases, id: \.self) { filter in
                        let isSelected = viewModel.selectedTripFilter == filter

                        Button {
                            viewModel.selectedTripFilter = filter
                        } label: {
                            Text(filter.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isSelected ? FMSTheme.obsidian : FMSTheme.textSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(isSelected ? FMSTheme.amber : FMSTheme.pillBackground)
                                .cornerRadius(20)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Trip list
            LazyVStack(spacing: 10) {
                if viewModel.filteredCompletedTrips.isEmpty {
                    emptyState(
                        icon: "clock.arrow.circlepath",
                        title: "No Trips Found",
                        subtitle: "Try adjusting your search or filters"
                    )
                } else {
                    ForEach(viewModel.filteredCompletedTrips) { trip in
                        Button {
                            selectedTrip = trip
                        } label: {
                            TripHistoryCard(trip: trip)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 32)
    }

    // MARK: - Empty State

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(FMSTheme.textTertiary)

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(FMSTheme.textPrimary)

            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(FMSTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}