import Foundation
import Observation

// MARK: - Break Reminder Level

public enum BreakReminderLevel: Int, Comparable, Codable {
    case none = 0
    case gentle = 1      // 2 hours
    case warning = 2     // 3.5 hours
    case critical = 3    // 4.5 hours

    public static func < (lhs: BreakReminderLevel, rhs: BreakReminderLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Fatigue Warning Level

public enum FatigueWarningLevel: Int, Comparable, Codable {
    case none = 0
    case warning = 1     // 4 hours
    case critical = 2    // 6 hours

    public static func < (lhs: FatigueWarningLevel, rhs: FatigueWarningLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Persisted State

private struct PersistedTimerState: Codable {
    var drivingStartDate: Date?
    var accumulatedBeforeBreak: TimeInterval
    var breakStartDate: Date?
    var isActive: Bool
    var isOnBreak: Bool
}

// MARK: - Driving Timer Manager

@MainActor
@Observable
public final class DrivingTimerManager {

    // MARK: - Configuration

    private let breakReminderGentleSeconds: TimeInterval = 2 * 3600
    private let breakReminderWarningSeconds: TimeInterval = 3.5 * 3600
    private let breakReminderCriticalSeconds: TimeInterval = 4.5 * 3600
    private let fatigueWarningSeconds: TimeInterval = 4 * 3600
    private let fatigueCriticalSeconds: TimeInterval = 6 * 3600
    private let minimumBreakResetSeconds: TimeInterval = 15 * 60

    private let persistenceKey = "fms_driving_timer_state"

    // MARK: - Public State

    public var isActive: Bool = false
    public var isOnBreak: Bool = false
    public var continuousDrivingSeconds: TimeInterval = 0
    public var currentBreakSeconds: TimeInterval = 0
    public var breakReminderLevel: BreakReminderLevel = .none
    public var fatigueWarningLevel: FatigueWarningLevel = .none
    public var breakReminderDismissed: Bool = false
    public var allRemindersHidden: Bool = false

    // MARK: - Private

    private var timer: Timer?
    private var drivingStartDate: Date?
    private var breakStartDate: Date?
    private var accumulatedDrivingBeforeBreak: TimeInterval = 0

    // MARK: - Init

    public init() {
        restoreState()
    }

    // MARK: - Public API

    public func startDriving() {
        guard !isActive else { return }
        isActive = true
        isOnBreak = false
        drivingStartDate = Date()
        accumulatedDrivingBeforeBreak = 0
        continuousDrivingSeconds = 0
        resetWarnings()
        persistState()
        startTimer()
    }

    public func stopDriving() {
        isActive = false
        isOnBreak = false
        timer?.invalidate()
        timer = nil
        drivingStartDate = nil
        breakStartDate = nil
        continuousDrivingSeconds = 0
        currentBreakSeconds = 0
        accumulatedDrivingBeforeBreak = 0
        resetWarnings()
        clearPersistedState()
    }

    public func startBreak() {
        guard isActive, !isOnBreak else { return }
        isOnBreak = true
        breakStartDate = Date()
        accumulatedDrivingBeforeBreak = continuousDrivingSeconds
        currentBreakSeconds = 0
        persistState()
    }

    public func endBreak() -> TimeInterval {
        guard isOnBreak, let breakStart = breakStartDate else { return 0 }
        let breakDuration = Date().timeIntervalSince(breakStart)
        isOnBreak = false
        breakStartDate = nil
        currentBreakSeconds = 0

        if breakDuration >= minimumBreakResetSeconds {
            continuousDrivingSeconds = 0
            accumulatedDrivingBeforeBreak = 0
            resetWarnings()
        } else {
            continuousDrivingSeconds = accumulatedDrivingBeforeBreak
        }

        drivingStartDate = Date()
        persistState()
        return breakDuration
    }

    public func dismissBreakReminder() {
        breakReminderDismissed = true
    }

    public func hideAllReminders() {
        allRemindersHidden = true
    }

    // MARK: - Formatted

    public var formattedDrivingTime: String {
        let total = Int(continuousDrivingSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }
        let seconds = total % 60
        return String(format: "%dm %02ds", minutes, seconds)
    }

    public var formattedBreakTime: String {
        let total = Int(currentBreakSeconds)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Private

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard isActive else { return }

        if isOnBreak {
            if let breakStart = breakStartDate {
                currentBreakSeconds = Date().timeIntervalSince(breakStart)
            }
        } else {
            if let drivingStart = drivingStartDate {
                continuousDrivingSeconds = accumulatedDrivingBeforeBreak + Date().timeIntervalSince(drivingStart)
            }
            updateWarningLevels()
        }
    }

    private func updateWarningLevels() {
        let seconds = continuousDrivingSeconds

        let newBreakLevel: BreakReminderLevel
        if seconds >= breakReminderCriticalSeconds {
            newBreakLevel = .critical
        } else if seconds >= breakReminderWarningSeconds {
            newBreakLevel = .warning
        } else if seconds >= breakReminderGentleSeconds {
            newBreakLevel = .gentle
        } else {
            newBreakLevel = .none
        }

        if newBreakLevel != breakReminderLevel {
            breakReminderLevel = newBreakLevel
            breakReminderDismissed = false
            allRemindersHidden = false
        }

        let newFatigueLevel: FatigueWarningLevel
        if seconds >= fatigueCriticalSeconds {
            newFatigueLevel = .critical
        } else if seconds >= fatigueWarningSeconds {
            newFatigueLevel = .warning
        } else {
            newFatigueLevel = .none
        }

        if newFatigueLevel != fatigueWarningLevel {
            fatigueWarningLevel = newFatigueLevel
        }
    }

    private func resetWarnings() {
        breakReminderLevel = .none
        fatigueWarningLevel = .none
        breakReminderDismissed = false
        allRemindersHidden = false
    }

    // MARK: - Persistence

    private func persistState() {
        let state = PersistedTimerState(
            drivingStartDate: drivingStartDate,
            accumulatedBeforeBreak: accumulatedDrivingBeforeBreak,
            breakStartDate: breakStartDate,
            isActive: isActive,
            isOnBreak: isOnBreak
        )
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: persistenceKey)
        }
    }

    private func restoreState() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let state = try? JSONDecoder().decode(PersistedTimerState.self, from: data),
              state.isActive else { return }

        isActive = state.isActive
        isOnBreak = state.isOnBreak
        drivingStartDate = state.drivingStartDate
        accumulatedDrivingBeforeBreak = state.accumulatedBeforeBreak
        breakStartDate = state.breakStartDate

        // Recalculate current driving/break time from persisted dates
        if isOnBreak {
            if let breakStart = breakStartDate {
                currentBreakSeconds = Date().timeIntervalSince(breakStart)
            }
        } else if let drivingStart = drivingStartDate {
            continuousDrivingSeconds = accumulatedDrivingBeforeBreak + Date().timeIntervalSince(drivingStart)
        }

        updateWarningLevels()
        startTimer()
    }

    private func clearPersistedState() {
        UserDefaults.standard.removeObject(forKey: persistenceKey)
    }
}
