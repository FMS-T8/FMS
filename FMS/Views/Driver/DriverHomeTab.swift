import SwiftUI

struct DriverHomeTab: View {
    @Bindable var viewModel: DriverDashboardViewModel
    @State private var showPreTripInspection = false
    @State private var showPostTripInspection = false
    @State private var preTripInspectionCompleted = false
    @State private var postTripInspectionCompleted = false
    @State private var showIssueReport = false
    @State private var showProfile = false
    @State private var selectedTrip: Trip?

    /// Trip to start after pre-trip inspection completes
    @State private var pendingStartTrip: Trip?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    currentJobSection
                    upcomingJobsSection
                    geofenceAlertsSection
                    quickActionsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(FMSTheme.backgroundPrimary)
            .fullScreenCover(isPresented: $showPreTripInspection) {
                InspectionChecklistView(
                    type: .preTrip,
                    vehicleId: viewModel.assignedVehicle?.id ?? "VH-001",
                    driverId: viewModel.driver.id,
                    onCompletion: {
                        preTripInspectionCompleted = true
                    }
                )
            }
            .fullScreenCover(isPresented: $showPostTripInspection) {
                InspectionChecklistView(
                    type: .postTrip,
                    vehicleId: viewModel.assignedVehicle?.id ?? "VH-001",
                    driverId: viewModel.driver.id,
                    onCompletion: {
                        postTripInspectionCompleted = true
                    }
                )
            }
            .sheet(isPresented: $showIssueReport) {
                IssueReportView(viewModel: viewModel)
            }
            .sheet(isPresented: $showProfile) {
                DriverProfileTab(viewModel: viewModel)
            }
            .navigationDestination(item: $selectedTrip) { trip in
                DriverTripDetailView(trip: trip, viewModel: viewModel)
            }
            .onChange(of: showPreTripInspection) { _, isShowing in
                if !isShowing {
                    if preTripInspectionCompleted, let trip = pendingStartTrip {
                        viewModel.startTrip(trip)
                    }
                    pendingStartTrip = nil
                    preTripInspectionCompleted = false
                }
            }
            .onChange(of: showPostTripInspection) { _, isShowing in
                // Only end the trip if the post-trip inspection was actually completed.
                if !isShowing {
                    if postTripInspectionCompleted {
                        viewModel.endTrip()
                    }
                    postTripInspectionCompleted = false
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hello, \(viewModel.driver.name.components(separatedBy: " ").first ?? "Driver")")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(FMSTheme.textPrimary)

                Text(formattedDate)
                    .font(.system(size: 14))
                    .foregroundStyle(FMSTheme.textSecondary)
            }

            Spacer()

            // Profile button (top-right)
            Button {
                showProfile = true
            } label: {
                Circle()
                    .fill(FMSTheme.borderLight)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(FMSTheme.textTertiary)
                    )
            }
        }
    }

    // MARK: - Current Job

    private var currentJobSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Current Job")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(FMSTheme.textPrimary)

                Spacer()

                if viewModel.currentJob != nil {
                    Text("PRIORITY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(FMSTheme.obsidian)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(FMSTheme.amber)
                        .cornerRadius(6)
                }
            }

            if let job = viewModel.currentJob {
                CurrentJobCard(
                    trip: job,
                    vehiclePlate: viewModel.assignedVehicle?.plateNumber,
                    isActive: viewModel.currentJobIsActive,
                    onStartJob: {
                        // Show pre-trip inspection first, then start trip
                        pendingStartTrip = job
                        preTripInspectionCompleted = false
                        showPreTripInspection = true
                    },
                    onDetails: { selectedTrip = job },
                    onEndTrip: {
                        // Show post-trip inspection first, then end trip
                        postTripInspectionCompleted = false
                        showPostTripInspection = true
                    }
                )
            } else {
                NoActiveTripCard()
            }
        }
    }

    // MARK: - Upcoming Jobs

    @ViewBuilder
    private var upcomingJobsSection: some View {
        let upcoming = viewModel.remainingUpcomingTrips
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Upcoming Jobs")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(FMSTheme.textPrimary)

                    Spacer()

                    Button("View All") {
                        viewModel.selectedSegment = .upcoming
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FMSTheme.amber)
                }

                ForEach(upcoming.prefix(3)) { trip in
                    UpcomingJobCard(trip: trip) {
                        selectedTrip = trip
                    }
                }
            }
        }
    }

    // MARK: - Geofence Alerts

    private var geofenceAlertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Alerts")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)

            ForEach(Array(geofenceAlerts.enumerated()), id: \.offset) { _, alert in
                AlertRow(
                    title: alert.title,
                    subtitle: alert.subtitle,
                    timeAgo: alert.timeAgo,
                    type: alert.type
                )
            }
        }
    }

    private let geofenceAlerts: [(title: String, subtitle: String, timeAgo: String, type: AlertType)] = [
        ("Geofence deviation", "You exited the designated route area near NH-48 junction.", "12m ago", .critical),
        ("Geofence re-entry", "Back on designated route corridor.", "8m ago", .info),
    ]

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)

            QuickActionCard(
                icon: "exclamationmark.bubble.fill",
                title: "Report Issue",
                subtitle: "Report a vehicle problem",
                action: { showIssueReport = true }
            )
        }
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: Date())
    }
}
