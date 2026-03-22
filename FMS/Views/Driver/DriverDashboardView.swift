import SwiftUI

public struct DriverDashboardView: View {
    @State private var viewModel = DriverDashboardViewModel()
    @State private var safetyViewModel = SafetyViewModel()
    @State private var breakLogViewModel: BreakLogViewModel?

    public init() {}

    public var body: some View {
        ZStack {
            FMSTabShell {
                FMSTabItem(id: "home", title: "Home", icon: "house.fill") {
                    DriverHomeTab(viewModel: viewModel)
                }

                FMSTabItem(id: "safety", title: "Safety", icon: "checkmark.shield.fill") {
                    DriverSafetyTab(
                        safetyViewModel: safetyViewModel,
                        breakLogViewModel: currentBreakLogViewModel,
                        hasActiveTrip: viewModel.hasActiveTrip
                    )
                }

                FMSTabItem(id: "trips", title: "Trips", icon: "map.fill") {
                    DriverTripsTab(viewModel: viewModel)
                }
            }

            // Floating SOS Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    SOSFloatingButton {
                        safetyViewModel.triggerManualSOS()
                    }
                    .padding(.trailing, 20)
                }
                .padding(.bottom, 90)
            }

            // Break Reminder Banner (top)
            if safetyViewModel.drivingTimer.breakReminderLevel != .none
                && !safetyViewModel.drivingTimer.breakReminderDismissed {
                VStack {
                    BreakReminderBannerView(
                        level: safetyViewModel.drivingTimer.breakReminderLevel,
                        drivingTime: safetyViewModel.drivingTimer.formattedDrivingTime,
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.25)) {
                                safetyViewModel.drivingTimer.dismissBreakReminder()
                            }
                            // If warning or critical, show bottom sheet after dismiss
                        },
                        onStartBreak: {
                            startBreakFromReminder()
                        }
                    )
                    .padding(.top, 8)
                    Spacer()
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: safetyViewModel.drivingTimer.breakReminderLevel)
            }

            // Break Reminder Bottom Sheet (escalated)
            if safetyViewModel.drivingTimer.breakReminderDismissed
                && safetyViewModel.drivingTimer.breakReminderLevel >= .warning {
                VStack {
                    Spacer()
                    BreakReminderBottomSheet(
                        level: safetyViewModel.drivingTimer.breakReminderLevel,
                        drivingTime: safetyViewModel.drivingTimer.formattedDrivingTime,
                        onStartBreak: {
                            startBreakFromReminder()
                        },
                        onDismiss: {
                            // Log as ignored but keep bottom sheet for critical
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
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: safetyViewModel.drivingTimer.breakReminderDismissed)
            }

            // Fatigue Warning Banner
            if safetyViewModel.showFatigueBanner {
                VStack {
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
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: safetyViewModel.showFatigueBanner)
            }

            // SOS Sent Banner
            if safetyViewModel.showSOSSentBanner {
                VStack {
                    SOSSentBanner {
                        withAnimation {
                            safetyViewModel.showSOSSentBanner = false
                        }
                    }
                    .padding(.top, 8)
                    Spacer()
                }
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
                updateBreakLogViewModel()
            } else {
                safetyViewModel.stopDriving()
                breakLogViewModel = nil
            }
        }
        .onAppear {
            requestNotificationPermission()
            if viewModel.hasActiveTrip {
                safetyViewModel.startDriving()
                updateBreakLogViewModel()
            }
        }
    }

    // MARK: - Helpers

    private var currentBreakLogViewModel: BreakLogViewModel {
        if let existing = breakLogViewModel { return existing }
        let vm = BreakLogViewModel(
            driverId: viewModel.driver.id,
            tripId: viewModel.activeTrip?.id ?? "",
            vehicleId: viewModel.assignedVehicle?.id ?? ""
        )
        return vm
    }

    private func updateBreakLogViewModel() {
        breakLogViewModel = BreakLogViewModel(
            driverId: viewModel.driver.id,
            tripId: viewModel.activeTrip?.id ?? "",
            vehicleId: viewModel.assignedVehicle?.id ?? ""
        )
    }

    private func startBreakFromReminder() {
        updateBreakLogViewModel()
        breakLogViewModel?.startBreak()
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
        .task {
            await viewModel.fetchLiveDashboardData()
        }
    }
}
