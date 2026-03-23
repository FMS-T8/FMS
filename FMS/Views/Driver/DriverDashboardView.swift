import SwiftUI
import UserNotifications

public struct DriverDashboardView: View {
    @State private var viewModel = DriverDashboardViewModel()
    @State private var safetyViewModel = SafetyViewModel()

    public init() {}

    public var body: some View {
        FMSTabShell {
            FMSTabItem(id: "home", title: "Home", icon: "house.fill") {
                DriverHomeTab(viewModel: viewModel)
            }

            FMSTabItem(id: "safety", title: "Safety", icon: "checkmark.shield.fill") {
                DriverSafetyTab(
                    safetyViewModel: safetyViewModel,
                    breakLogViewModel: currentBreakLogViewModel,
                    hasActiveTrip: viewModel.hasActiveTrip,
                    driverId: viewModel.driver.id,
                    tripId: viewModel.activeTrip?.id ?? ""
                )
            }

            FMSTabItem(id: "trips", title: "Trips", icon: "map.fill") {
                DriverTripsTab(viewModel: viewModel)
            }
        }
        // Floating SOS Button — overlay so no spacers eat scroll gestures
        .overlay(alignment: .bottomTrailing) {
            SOSFloatingButton {
                safetyViewModel.triggerManualSOS()
            }
            .padding(.trailing, 20)
            .padding(.bottom, 90)
        }
        // Break Reminder Banner (top)
        .overlay(alignment: .top) {
            if safetyViewModel.drivingTimer.breakReminderLevel != .none
                && !safetyViewModel.drivingTimer.breakReminderDismissed {
                BreakReminderBannerView(
                    level: safetyViewModel.drivingTimer.breakReminderLevel,
                    drivingTime: safetyViewModel.drivingTimer.formattedDrivingTime,
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            safetyViewModel.drivingTimer.dismissBreakReminder()
                        }
                    },
                    onStartBreak: {
                        startBreakFromReminder()
                    }
                )
                .padding(.top, 8)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: safetyViewModel.drivingTimer.breakReminderLevel)
            }
        }
        // Break Reminder Bottom Sheet (escalated)
        .overlay(alignment: .bottom) {
            if safetyViewModel.drivingTimer.breakReminderDismissed
                && safetyViewModel.drivingTimer.breakReminderLevel >= .warning {
                BreakReminderBottomSheet(
                    level: safetyViewModel.drivingTimer.breakReminderLevel,
                    drivingTime: safetyViewModel.drivingTimer.formattedDrivingTime,
                    onStartBreak: {
                        startBreakFromReminder()
                    },
                    onDismiss: {
                        if safetyViewModel.drivingTimer.breakReminderLevel == .critical {
                            // Critical stays persistent
                        } else {
                            withAnimation(.easeOut(duration: 0.25)) {
                                safetyViewModel.drivingTimer.breakReminderDismissed = false
                            }
                        }
                    }
                )
                .padding(.bottom, 100)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: safetyViewModel.drivingTimer.breakReminderDismissed)
            }
        }
        // Fatigue Warning Banner
        .overlay(alignment: .top) {
            if safetyViewModel.showFatigueBanner {
                FatigueBanner(
                    message: safetyViewModel.fatigueBannerMessage,
                    isCritical: safetyViewModel.fatigueBannerIsCritical,
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            safetyViewModel.dismissFatigueBanner()
                        }
                    }
                )
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: safetyViewModel.showFatigueBanner)
            }
        }
        // SOS Sent Banner
        .overlay(alignment: .top) {
            if safetyViewModel.showSOSSentBanner {
                SOSSentBanner {
                    withAnimation {
                        safetyViewModel.showSOSSentBanner = false
                    }
                }
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        // SOS Countdown — route completion to correct handler based on flow type
        .fullScreenCover(isPresented: $safetyViewModel.showSOSCountdown) {
            SOSCountdownView(
                viewModel: SOSViewModel(
                    driverId: viewModel.driver.id,
                    vehicleId: viewModel.assignedVehicle?.id ?? "",
                    tripId: viewModel.activeTrip?.id
                ),
                onSOSSent: {
                    if safetyViewModel.isImpactDrivenSOS {
                        safetyViewModel.impactSOSCompleted()
                    } else {
                        safetyViewModel.manualSOSSent()
                    }
                },
                onCancelled: { safetyViewModel.manualSOSCancelled() }
            )
        }
        // Safety Confirmation (after impact)
        .fullScreenCover(isPresented: $safetyViewModel.showSafetyConfirmation) {
            SafetyConfirmationView(safetyViewModel: safetyViewModel)
        }
        // Monitor crash detection
        .onChange(of: safetyViewModel.crashService.impactDetected) { _, detected in
            if detected {
                safetyViewModel.onImpactDetected()
            }
        }
        // Monitor fatigue
        .onChange(of: safetyViewModel.drivingTimer.fatigueWarningLevel) { _, _ in
            safetyViewModel.checkFatigueWarnings()
        }
        // Start/stop driving with trip lifecycle
        .onChange(of: viewModel.hasActiveTrip) { _, hasTrip in
            if hasTrip {
                safetyViewModel.startDriving()
            } else {
                safetyViewModel.stopDriving()
                viewModel.breakLogViewModel.stopLocationUpdates()
            }
        }
        .onAppear {
            requestNotificationPermission()
            if viewModel.hasActiveTrip {
                safetyViewModel.startDriving()
            }
        }
        .task {
            await viewModel.fetchLiveDashboardData()
        }
    }

    // MARK: - Helpers

    private var currentBreakLogViewModel: BreakLogViewModel {
        viewModel.breakLogViewModel
    }


    private func startBreakFromReminder() {
        viewModel.breakLogViewModel.startBreak()
        safetyViewModel.drivingTimer.startBreak()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}

// MARK: - Fatigue Banner

private struct FatigueBanner: View {
    let message: String
    let isCritical: Bool
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isCritical ? FMSTheme.alertRed : FMSTheme.alertOrange)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(FMSTheme.textPrimary)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(FMSTheme.textTertiary)
                    .padding(5)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(FMSTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke((isCritical ? FMSTheme.alertRed : FMSTheme.alertOrange).opacity(0.4), lineWidth: 1.5)
        )
        .shadow(color: FMSTheme.shadowSmall, radius: 4, y: 2)
        .padding(.horizontal, 16)
    }
}

// MARK: - SOS Sent Banner

private struct SOSSentBanner: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(FMSTheme.alertGreen)

            Text("SOS alert sent to fleet manager")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(FMSTheme.textPrimary)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(FMSTheme.textTertiary)
                    .padding(5)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(FMSTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(FMSTheme.alertGreen.opacity(0.4), lineWidth: 1.5)
        )
        .shadow(color: FMSTheme.shadowSmall, radius: 4, y: 2)
        .padding(.horizontal, 16)
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(5))
                onDismiss()
            }
        }
    }
}
