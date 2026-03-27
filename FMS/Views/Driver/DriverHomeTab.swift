import SwiftUI

struct DriverHomeTab: View {
    @Bindable var viewModel: DriverDashboardViewModel
    @Environment(BannerManager.self) private var bannerManager
    @State private var showPreTripInspection = false
    @State private var showPostTripInspection = false
    @State private var preTripInspectionCompleted = false
    @State private var postTripInspectionCompleted = false
    @State private var showIssueReport = false
    @State private var showFuelReceipt = false
    @State private var showProfile = false
    @State private var selectedTrip: Trip?
    @State private var showLocationConfirmation = false

    /// Trip to start after pre-trip inspection completes
    @State private var pendingStartTrip: Trip?
    @State private var showAllUpcomingJobs = false

    var body: some View {
        NavigationStack {
            ZStack {
                FMSTheme.backgroundPrimary.ignoresSafeArea()
                
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
            }
            .refreshable {
                await viewModel.fetchLiveDashboardData()
            }
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
            .sheet(isPresented: $showFuelReceipt) {
                FuelReceiptScannerEntryView(tripID: viewModel.currentJob?.id)
            }
            .sheet(isPresented: $showProfile) {
                DriverProfileTab(viewModel: viewModel)
            }
            .navigationDestination(item: $selectedTrip) { trip in
                NewTripAssignmentView(trip: trip, viewModel: viewModel)
            }
            .navigationDestination(isPresented: $showAllUpcomingJobs) {
                AllUpcomingJobsView(viewModel: viewModel)
            }
            .onChange(of: showPreTripInspection) { _, isShowing in
                if !isShowing {
                    if preTripInspectionCompleted, let trip = pendingStartTrip {
                        viewModel.startTrip(trip)
                        showLocationConfirmation = true
                    }
                    preTripInspectionCompleted = false
                }
            }
            .fullScreenCover(isPresented: $showLocationConfirmation) {
                if let trip = pendingStartTrip ?? viewModel.currentJob {
                    LocationTrackingConfirmationView(trip: trip)
                }
            }
            .onChange(of: showLocationConfirmation) { _, isShowing in
                if !isShowing {
                    pendingStartTrip = nil
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
            .onChange(of: viewModel.breakLogViewModel.errorMessage) { _, msg in
                if let msg {
                    bannerManager.show(type: .error, message: msg)
                    viewModel.breakLogViewModel.errorMessage = nil
                }
            }
            .onChange(of: viewModel.errorMessage) { _, msg in
                if let msg {
                    bannerManager.show(type: .error, message: msg)
                    viewModel.errorMessage = nil
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
            }

            if let job = viewModel.currentJob {
                CurrentJobCard(
                    trip: job,
                    vehiclePlate: viewModel.assignedVehicle?.plateNumber,
                    isActive: viewModel.currentJobIsActive,
                    isOnBreak: viewModel.breakLogViewModel.isOnBreak,
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
                    },
                    onLogBreak: nil
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
                Text("Upcoming Jobs")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(FMSTheme.textPrimary)

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

            if viewModel.alerts.isEmpty {
                Text("No active alerts for this trip")
                    .font(.system(size: 14))
                    .foregroundStyle(FMSTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.alerts) { alert in
                    AlertRow(
                        title: titleFor(alert),
                        subtitle: alert.message ?? "No details available",
                        timeAgo: timeAgoFor(alert.createdAt),
                        type: typeFor(alert)
                    )
                }
            }
        }
    }

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

            QuickActionCard(
                icon: "fuelpump.fill",
                title: "Log Fuel Receipt",
                subtitle: "Scan and submit fueling details",
                action: { showFuelReceipt = true }
            )
        }
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: Date())
    }

    private func titleFor(_ alert: Notification) -> String {
        switch alert.type {
        case "geofence_entry": return "Geofence re-entry"
        case "geofence_exit": return "Geofence deviation"
        case "document_expiry": return "Document Expiring"
        case "maintenance_due": return "Maintenance Due"
        case "crash_alert": return "Impact Detected"
        case "break_violation": return "Break Violation"
        default: return "Trip Alert"
        }
    }

    private func typeFor(_ alert: Notification) -> AlertType {
        switch alert.type {
        case "geofence_exit", "crash_alert", "break_violation": return .critical
        case "maintenance_due", "document_expiry": return .warning
        default: return .info
        }
    }

    private func timeAgoFor(_ date: Date?) -> String {
        guard let date = date else { return "Just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
