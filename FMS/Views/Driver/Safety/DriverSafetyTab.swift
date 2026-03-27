import SwiftUI

struct DriverSafetyTab: View {
    @Bindable var safetyViewModel: SafetyViewModel
    @Bindable var breakLogViewModel: BreakLogViewModel
    let hasActiveTrip: Bool
    let driverId: String
    let tripId: String

    var body: some View {
        NavigationStack {
            ZStack {
                FMSTheme.backgroundPrimary.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        
                        if hasActiveTrip {
                            breakLoggingSection
                        } else {
                            noActiveTripCard
                        }
                        
                        safetyEventsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .refreshable {
                await breakLogViewModel.fetchBreakHistory()
                safetyViewModel.checkFatigueWarnings()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Safety")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)

            Text("Emergency tools and break management")
                .font(.system(size: 14))
                .foregroundStyle(FMSTheme.textSecondary)
        }
    }

    // MARK: - Break Logging

    private var breakLoggingSection: some View {
        BreakLoggingView(
            viewModel: breakLogViewModel,
            drivingTimer: safetyViewModel.drivingTimer,
            driverId: driverId,
            tripId: tripId
        )
    }

    // MARK: - No Active Trip

    private var noActiveTripCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "pause.circle")
                .font(.system(size: 28))
                .foregroundStyle(FMSTheme.textTertiary)

            Text("No Active Trip")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(FMSTheme.textSecondary)

            Text("Break logging is available during active trips")
                .font(.system(size: 13))
                .foregroundStyle(FMSTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(FMSTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(FMSTheme.borderLight, lineWidth: 1)
        )
    }

    // MARK: - Safety Events

    private var safetyEventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Safety Status")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)

            SafetyStatusRow(
                icon: "checkmark.shield.fill",
                title: "Crash Detection",
                status: safetyViewModel.crashService.isMonitoring ? "Active" : "Inactive",
                isActive: safetyViewModel.crashService.isMonitoring
            )

            SafetyStatusRow(
                icon: breakLogViewModel.isOnBreak ? "pause.circle.fill" : "timer",
                title: breakLogViewModel.isOnBreak ? "On Break" : "Driving Timer",
                status: breakLogViewModel.isOnBreak
                    ? breakLogViewModel.formattedElapsed
                    : (safetyViewModel.drivingTimer.isActive
                        ? safetyViewModel.drivingTimer.formattedDrivingTime
                        : "Not tracking"),
                isActive: breakLogViewModel.isOnBreak || safetyViewModel.drivingTimer.isActive
            )

            SafetyStatusRow(
                icon: "bell.badge.fill",
                title: "Break Reminders",
                status: breakReminderStatusText,
                isActive: safetyViewModel.drivingTimer.isActive
                    && safetyViewModel.drivingTimer.breakReminderLevel < .warning
            )
        }
    }

    private var breakReminderStatusText: String {
        switch safetyViewModel.drivingTimer.breakReminderLevel {
        case .none: return "No reminders pending"
        case .gentle: return "Gentle reminder active"
        case .warning: return "Warning active"
        case .critical: return "CRITICAL"
        }
    }
}

// MARK: - Safety Status Row

private struct SafetyStatusRow: View {
    let icon: String
    let title: String
    let status: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isActive ? FMSTheme.alertGreen : FMSTheme.textTertiary)
                .frame(width: 32, height: 32)
                .background((isActive ? FMSTheme.alertGreen : FMSTheme.textTertiary).opacity(0.12))
                .cornerRadius(8)

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FMSTheme.textPrimary)

            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .fill(isActive ? FMSTheme.alertGreen : FMSTheme.textTertiary)
                    .frame(width: 6, height: 6)

                Text(status)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FMSTheme.textSecondary)
            }
        }
        .padding(12)
        .background(FMSTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(FMSTheme.borderLight, lineWidth: 1)
        )
    }
}
