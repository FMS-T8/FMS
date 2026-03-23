import Foundation
import UserNotifications
import Supabase

public final class SmartAlertService {
    public static let shared = SmartAlertService()
    
    private var batchFirstIssueTime: Date?
    private var batchCount: Int = 0
    
    private init() {
    }
    
    /// Main entry point for processing a new issue report
    public func handleNewIssue(_ report: IssueReport) {
        switch report.severity {
        case .critical:
            // Critical → instant push notification with sound, vibration
            sendNotification(
                title: "CRITICAL: Vehicle Issue Reported",
                body: "A critical vehicle issue requires immediate attention.",
                sound: .defaultCritical,
                priority: .critical,
                userInfo: [
                    "vehicleId": report.vehicleId ?? "Unknown",
                    "description": report.description ?? "",
                    "issueId": report.id
                ]
            )
            scheduleEscalationCheck(for: report, after: 600) // 10 minutes
            
        case .high:
            // High → push notification without sound (medium priority)
            sendNotification(
                title: "High Priority Vehicle Issue",
                body: "A high priority vehicle issue has been reported.",
                sound: nil,
                priority: .active,
                userInfo: [
                    "vehicleId": report.vehicleId ?? "Unknown",
                    "description": report.description ?? "",
                    "issueId": report.id
                ]
            )
            scheduleEscalationCheck(for: report, after: 1800) // 30 minutes
            
        case .medium, .low:
            // Medium or Low → only stored/displayed, summary message if multiple occur
            addToBatch(report)
        }
    }
    
    private func sendNotification(
        title: String,
        body: String,
        sound: UNNotificationSound?,
        priority: UNNotificationInterruptionLevel,
        userInfo: [AnyHashable: Any] = [:]
    ) {
        // Request authorization right before adding to ensure first-use isn't dropped
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert]) { granted, error in
            guard granted else {
                if let error = error { print("Notification permission error: \(error)") }
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = sound
            content.interruptionLevel = priority
            content.userInfo = userInfo
            
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil // Immediate
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error adding notification: \(error)")
                }
            }
        }
    }
    
    // MARK: - Batching Logic
    
    private func addToBatch(_ report: IssueReport) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let now = Date()
            
            if let first = self.batchFirstIssueTime, now.timeIntervalSince(first) >= 600 {
                // Outside the 10-15 min window, reset
                self.batchFirstIssueTime = nil
                self.batchCount = 0
            }
            
            if self.batchFirstIssueTime == nil {
                self.batchFirstIssueTime = now
            }
            
            self.batchCount += 1
            self.scheduleBatchNotification()
        }
    }
    
    private func scheduleBatchNotification() {
        guard let first = batchFirstIssueTime else { return }
        let count = batchCount
        
        // Only notify if multiple issues occurred
        guard count >= 2 else { return }
        
        let elapsed = Date().timeIntervalSince(first)
        let remaining = max(1.0, 600.0 - elapsed)
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert]) { granted, _ in
            guard granted else { return }
            
            let content = UNMutableNotificationContent()
            content.title = "New Vehicle Issues"
            content.body = "\(count) new vehicle issues reported in the last 10 minutes."
            content.sound = .default
            content.interruptionLevel = .passive
            // Keep body generic and lock screen safe
            
            // Scheduling over the same identifier replaces the pending request, 
            // essentially acting as a lockless background accumulator
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
            let request = UNNotificationRequest(identifier: "BatchSummary", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling batch notification: \(error)")
                }
            }
        }
    }
    
    // MARK: - Escalation Logic
    
    private func scheduleEscalationCheck(for report: IssueReport, after duration: TimeInterval) {
        // Schedule local notification to avoid process-bound process limits
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert]) { granted, _ in
            guard granted else { return }
            
            let content = UNMutableNotificationContent()
            content.title = "ESCALATION: Unresolved Issue"
            content.body = "Attention: A previously reported \(report.severity.rawValue) issue remains unresolved."
            content.sound = report.severity == .critical ? .defaultCritical : .default
            content.interruptionLevel = report.severity == .critical ? .critical : .active
            content.userInfo = [
                "issueId": report.id,
                "vehicleId": report.vehicleId ?? "Unknown"
            ]
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)
            let request = UNNotificationRequest(identifier: "Escalation_\(report.id)", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error adding escalation notification: \(error)")
                }
            }
        }
    }
    
    public func cancelEscalation(for issueId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["Escalation_\(issueId)"])
    }
}
