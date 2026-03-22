import Foundation
import UserNotifications
import Supabase

public final class SmartAlertService {
    public static let shared = SmartAlertService()
    
    private var pendingBatch: [IssueReport] = []
    private var batchTimer: Timer?
    
    private init() {
        requestNotificationPermission()
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    /// Main entry point for processing a new issue report
    public func handleNewIssue(_ report: IssueReport) {
        switch report.severity {
        case .critical:
            // Critical → instant push notification with sound, vibration (implemented via .default sound)
            sendNotification(
                title: "CRITICAL: Vehicle Issue Reported",
                body: "Vehicle \(report.vehicleId ?? "Unknown"): \(report.description)",
                sound: .default,
                priority: .critical
            )
            scheduleEscalationCheck(for: report, after: 600) // 10 minutes
            
        case .high:
            // High → push notification without sound (medium priority)
            sendNotification(
                title: "High Priority Vehicle Issue",
                body: "Vehicle \(report.vehicleId ?? "Unknown"): \(report.description)",
                sound: nil,
                priority: .active
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
        priority: UNNotificationInterruptionLevel
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        content.interruptionLevel = priority
        
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
    
    // MARK: - Batching Logic
    
    private func addToBatch(_ report: IssueReport) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.pendingBatch.append(report)
            
            // If this is the second issue in 10-15 mins, or if it's been more than 10 mins since last batch
            // The requirement: "If multiple low/medium severity issues occur within a short time window (10-15 mins) -> Send a single summary"
            if self.batchTimer == nil {
                self.batchTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: false) { [weak self] _ in
                    self?.sendBatchNotification()
                }
            } else if self.pendingBatch.count >= 2 {
                // If we already have multiple, we could potentially accelerate if we wanted, 
                // but let's stick to the 10m window. 
                // The requirement implies a single notification for the window.
            }
        }
    }
    
    private func sendBatchNotification() {
        let count = pendingBatch.count
        guard count > 0 else {
            batchTimer = nil
            return
        }
        
        // Only send if multiple issues occurred, otherwise just store (no individual notification for low/medium)
        if count >= 2 {
            sendNotification(
                title: "New Vehicle Issues",
                body: "\(count) new vehicle issues reported",
                sound: nil,
                priority: .passive
            )
        }
        
        pendingBatch.removeAll()
        batchTimer = nil
    }
    
    // MARK: - Escalation Logic
    
    private func scheduleEscalationCheck(for report: IssueReport, after duration: TimeInterval) {
        Task {
            // Wait for the duration (10m for Critical, 30m for High)
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            
            // Verify if issue is still "open" in Supabase
            do {
                let response: [Defect] = try await SupabaseService.shared.client
                    .from("defects")
                    .select()
                    .eq("id", value: report.id)
                    .execute()
                    .value
                
                if let currentStatus = response.first?.status, currentStatus == "open" {
                    triggerEscalationAlert(for: report)
                }
            } catch {
                print("Escalation check failed: \(error)")
            }
        }
    }
    
    private func triggerEscalationAlert(for report: IssueReport) {
        sendNotification(
            title: "ESCALATION: Unresolved Issue",
            body: "Attention: The \(report.severity.rawValue) issue for vehicle \(report.vehicleId ?? "Unknown") remains unresolved.",
            sound: .default,
            priority: .critical
        )
    }
}
