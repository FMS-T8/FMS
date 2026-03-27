import Foundation
import Observation

public enum SafetyFlowState: Equatable {
    case idle
    case impactDetected
    case awaitingConfirmation(secondsRemaining: Int)
    case sosTriggered
}

@MainActor
@Observable
public final class SafetyViewModel {

    // MARK: - State

    public var flowState: SafetyFlowState = .idle
    public var showSafetyConfirmation: Bool = false
    public var showSOSCountdown: Bool = false
    public var showSOSSentBanner: Bool = false
    public var showFatigueBanner: Bool = false
    public var fatigueBannerMessage: String = ""
    public var fatigueBannerIsCritical: Bool = false

    /// Tracks whether current SOS flow was triggered by impact (vs manual)
    public var isImpactDrivenSOS: Bool = false

    // MARK: - Dependencies

    public let crashService: CrashDetectionService
    public let drivingTimer: DrivingTimerManager

    // MARK: - Configuration

    private let impactDelaySeconds: TimeInterval = 5
    private let confirmationTimeoutSeconds = 30

    // MARK: - Private

    private var confirmationTargetDate: Date?
    private var confirmationTask: Task<Void, Never>?
    private var delayTask: Task<Void, Never>?
    private var lastFatigueLevel: FatigueWarningLevel = .none

    // MARK: - Init

    public init(
        crashService: CrashDetectionService,
        drivingTimer: DrivingTimerManager
    ) {
        self.crashService = crashService
        self.drivingTimer = drivingTimer
    }

    public convenience init() {
        self.init(crashService: .shared, drivingTimer: DrivingTimerManager())
    }

    // MARK: - Crash Flow (Impact-Driven)

    public func onImpactDetected() {
        guard case .idle = flowState else { return }
        flowState = .impactDetected
        isImpactDrivenSOS = true

        delayTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(impactDelaySeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            showSafetyConfirmation = true
            startConfirmationTimeout()
        }
    }

    public func driverConfirmedOK() {
        cancelConfirmationTimer()
        showSafetyConfirmation = false
        crashService.clearImpact()
        isImpactDrivenSOS = false
        flowState = .idle
    }

    public func driverNeedsHelp() {
        cancelConfirmationTimer()
        showSafetyConfirmation = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            self.triggerSOSFromImpact()
        }
    }

    /// Called when an impact-driven SOS has been sent successfully.
    public func impactSOSCompleted() {
        delayTask?.cancel()
        delayTask = nil
        showSOSCountdown = false
        showSOSSentBanner = true
        crashService.clearImpact()
        isImpactDrivenSOS = false
        flowState = .idle
    }

    // MARK: - Manual SOS (no crash flow)

    public func triggerManualSOS() {
        // Cancel any in-flight impact delay to prevent overlapping flows
        delayTask?.cancel()
        delayTask = nil
        cancelConfirmationTimer()
        showSafetyConfirmation = false
        crashService.clearImpact()
        flowState = .idle

        isImpactDrivenSOS = false
        showSOSCountdown = true
    }

    public func manualSOSCancelled() {
        showSOSCountdown = false
    }

    /// Called when a manually-triggered SOS is sent. Shows banner only (no checklist).
    public func manualSOSSent() {
        showSOSCountdown = false
        showSOSSentBanner = true
        // Manual SOS does NOT advance to checklist
    }

    // MARK: - Fatigue Monitoring

    public func checkFatigueWarnings() {
        let level = drivingTimer.fatigueWarningLevel
        guard level != lastFatigueLevel else { return }
        lastFatigueLevel = level

        switch level {
        case .none:
            showFatigueBanner = false
            return
        case .warning:
            fatigueBannerMessage = "You've been driving for 4 hours. Consider taking a break."
            fatigueBannerIsCritical = false
            showFatigueBanner = true
        case .critical:
            fatigueBannerMessage = "CRITICAL: 6 hours continuous driving. Take a break now."
            fatigueBannerIsCritical = true
            showFatigueBanner = true
        }
    }

    public func dismissFatigueBanner() {
        showFatigueBanner = false
    }

    // MARK: - Driving Timer Proxy

    public func startDriving() {
        drivingTimer.startDriving()
        crashService.startMonitoring()
    }

    public func stopDriving() {
        drivingTimer.stopDriving()
        crashService.stopMonitoring()
        lastFatigueLevel = .none
        showFatigueBanner = false
    }

    // MARK: - Private

    private func triggerSOSFromImpact() {
        flowState = .sosTriggered
        isImpactDrivenSOS = true
        showSOSCountdown = true
    }

    /// Uses target-date approach so countdown survives app backgrounding.
    /// Fix: Uses Task.sleep instead of Timer to comply with Swift 6 Concurrency Sendable tracking.
    private func startConfirmationTimeout() {
        let target = Date().addingTimeInterval(TimeInterval(confirmationTimeoutSeconds))
        confirmationTargetDate = target
        flowState = .awaitingConfirmation(secondsRemaining: confirmationTimeoutSeconds)

        confirmationTask?.cancel()
        confirmationTask = Task { @MainActor [weak self] in
            while let self = self {
                if Task.isCancelled { break }
                guard let target = self.confirmationTargetDate else { break }
                let remaining = Int(ceil(target.timeIntervalSinceNow))
                if remaining <= 0 {
                    self.confirmationTimedOut()
                    break
                } else {
                    self.flowState = .awaitingConfirmation(secondsRemaining: remaining)
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    private func confirmationTimedOut() {
        showSafetyConfirmation = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            self.triggerSOSFromImpact()
        }
    }

    private func cancelConfirmationTimer() {
        confirmationTask?.cancel()
        confirmationTask = nil
        confirmationTargetDate = nil
        delayTask?.cancel()
        delayTask = nil
    }
}
