import SwiftUI

// MARK: - DriverDetailView

/// Detail screen for a single driver, navigated to via `NavigationLink`
/// from `DriverCardView`.
///
/// Sections:
/// 1. Driver Profile
/// 2. Assigned Vehicle
/// 3. Shift Status
/// 4. Current Trip
/// 5. Break History
/// 6. Driving Incidents
struct DriverDetailView: View {

    @State private var vm: DriverDetailViewModel

    init(driver: DriverDisplayItem) {
        _vm = State(initialValue: DriverDetailViewModel(driver: driver))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                profileSection
                vehicleSection
                shiftSection
                tripSection
                breakHistorySection
                incidentsSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(FMSTheme.backgroundPrimary)
        .navigationTitle(vm.driverName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Section 1: Driver Profile

    private var profileSection: some View {
        SectionCard {
            HStack(spacing: 14) {
                AvatarCircle(
                    initials: String(vm.driverName.prefix(2)).uppercased(),
                    color: profileColor,
                    size: 60
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.driverName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(FMSTheme.textPrimary)
                    Text("ID: \(vm.employeeID)")
                        .font(.system(size: 14))
                        .foregroundStyle(FMSTheme.textSecondary)
                    StatusBadge(status: vm.availabilityStatus)
                }
                Spacer()
            }
        }
    }

    // MARK: - Section 2: Assigned Vehicle

    private var vehicleSection: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Assigned Vehicle", icon: "truck.box.fill")

                if let v = vm.vehicle {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(v.manufacturer ?? "—") \(v.model ?? "—")")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(FMSTheme.textPrimary)
                        Text("Plate: \(v.plateNumber)")
                            .font(.system(size: 14))
                            .foregroundStyle(FMSTheme.textSecondary)
                    }
                } else {
                    Text("No vehicle assigned")
                        .font(.system(size: 14))
                        .foregroundStyle(FMSTheme.textTertiary)
                }
            }
        }
    }

    // MARK: - Section 3: Shift Status

    private var shiftSection: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Shift Status", icon: "clock.fill")

                HStack {
                    InfoLabel(title: "Start", value: vm.shiftStartLabel)
                    Spacer()
                    InfoLabel(title: "End", value: vm.shiftEndLabel)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Progress")
                            .font(.system(size: 12))
                            .foregroundStyle(FMSTheme.textSecondary)
                        Spacer()
                        Text(vm.shiftProgressLabel)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(FMSTheme.textPrimary)
                    }
                    ProgressView(value: vm.shiftProgress)
                        .tint(FMSTheme.amber)
                }
            }
        }
    }

    // MARK: - Section 4: Current Trip

    private var tripSection: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Current Trip", icon: "location.fill")

                if let route = vm.tripRouteLabel {
                    Text(route)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(FMSTheme.textPrimary)
                    HStack(spacing: 16) {
                        InfoLabel(title: "Status", value: vm.tripStatusLabel)
                        if let dist = vm.tripDistanceLabel {
                            InfoLabel(title: "Distance", value: dist)
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "car.side")
                            .foregroundStyle(FMSTheme.textTertiary)
                        Text("No active trip")
                            .font(.system(size: 14))
                            .foregroundStyle(FMSTheme.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: - Section 5: Break History

    private var breakHistorySection: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Break History", icon: "cup.and.saucer.fill")

                if vm.breakLogs.isEmpty {
                    Text("No breaks recorded")
                        .font(.system(size: 14))
                        .foregroundStyle(FMSTheme.textTertiary)
                } else {
                    ForEach(vm.breakLogs) { brk in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Break")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(FMSTheme.textPrimary)
                                Text(vm.formatTime(brk.startTime))
                                    .font(.system(size: 12))
                                    .foregroundStyle(FMSTheme.textSecondary)
                            }
                            Spacer()
                            if let dur = brk.durationMinutes {
                                Text("\(dur) minutes")
                                    .font(.system(size: 13))
                                    .foregroundStyle(FMSTheme.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                        if brk.id != vm.breakLogs.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Section 6: Driving Incidents

    private var incidentsSection: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Driving Incidents", icon: "exclamationmark.triangle.fill")

                if vm.incidents.isEmpty {
                    Text("No incidents recorded")
                        .font(.system(size: 14))
                        .foregroundStyle(FMSTheme.textTertiary)
                } else {
                    ForEach(vm.incidents) { incident in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(incident.severity ?? "Incident")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(FMSTheme.textPrimary)
                                Text(vm.formatTime(incident.createdAt))
                                    .font(.system(size: 12))
                                    .foregroundStyle(FMSTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(FMSTheme.alertRed.opacity(0.7))
                        }
                        .padding(.vertical, 4)
                        if incident.id != vm.incidents.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var profileColor: Color {
        switch vm.availabilityStatus {
        case .available: return FMSTheme.alertGreen
        case .onTrip:    return FMSTheme.amber
        case .offDuty:   return FMSTheme.textTertiary
        }
    }
}

// MARK: - Reusable Detail Subcomponents

/// Card container for detail sections.
private struct SectionCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FMSTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

/// Section header with icon and title.
private struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(FMSTheme.amber)
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)
        }
        .padding(.bottom, 4)
    }
}

/// Small label with title + value.
private struct InfoLabel: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(FMSTheme.textTertiary)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(FMSTheme.textPrimary)
        }
    }
}
