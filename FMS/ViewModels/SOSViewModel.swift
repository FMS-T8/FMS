import Foundation
import CoreLocation
import Observation
import UserNotifications
import Supabase
import UIKit

@MainActor
@Observable
public final class SOSViewModel: NSObject, CLLocationManagerDelegate {

    public enum SOSState: Equatable {
        case idle
        case countdown(secondsRemaining: Int)
        case sending
        case active
        case failed(retryAvailable: Bool)
    }

    public var state: SOSState = .idle
    public var isSOSActive: Bool { if case .active = state { return true } else { return false } }
    public var sendFailed: Bool = false
    public var alertStatus: SOSAlertStatus = .active
    public var isAcknowledged: Bool { alertStatus == .acknowledged }
    public var isResolved: Bool     { alertStatus == .resolved }
    
    // MARK: - Error Handling State
    public var errorMessage: String? = nil
    public var showError: Bool = false

    public let countdownDuration = 10

    private var countdownTargetDate: Date?
    private var countdownTask: Task<Void, Never>?
    private var locationManager: CLLocationManager?
    private var currentLocation: CLLocation?
    private var pingTask: Task<Void, Never>?
    private var pingCount = 0
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var sosAlertId: String?
    private var statusPollTask: Task<Void, Never>?

    private let driverId:  String
    private let vehicleId: String
    private let tripId:    String?

    public init(driverId: String, vehicleId: String, tripId: String? = nil) {
        self.driverId  = driverId
        self.vehicleId = vehicleId
        self.tripId    = tripId
        super.init()
        setupLocationManager()
    }

    public func startCountdown() {
        guard case .idle = state else { return }
        let target = Date().addingTimeInterval(TimeInterval(countdownDuration))
        countdownTargetDate = target
        state = .countdown(secondsRemaining: countdownDuration)

        countdownTask?.cancel()
        countdownTask = Task { @MainActor [weak self] in
            while let self = self {
                if Task.isCancelled { break }
                guard let target = self.countdownTargetDate else { break }
                
                let remaining = Int(ceil(target.timeIntervalSinceNow))
                if remaining <= 0 {
                    self.sendSOS()
                    break
                } else {
                    self.state = .countdown(secondsRemaining: remaining)
                }
                
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    public func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask       = nil
        countdownTargetDate = nil
        state               = .idle
    }

    public func sendSOS() {
        countdownTask?.cancel()
        countdownTask       = nil
        countdownTargetDate = nil
        state               = .sending
        sendFailed          = false
        errorMessage        = nil
        showError           = false

        beginBackgroundTask()

        let lat   = currentLocation?.coordinate.latitude  ?? 0
        let lng   = currentLocation?.coordinate.longitude ?? 0
        let speed = currentLocation?.speed ?? 0

        let alertId = UUID().uuidString
        sosAlertId  = alertId

        let alert = SOSAlertInsert(
            id:        alertId,
            driverId:  driverId,
            vehicleId: vehicleId,
            tripId:    tripId,
            latitude:  lat,
            longitude: lng,
            speed:     max(0, speed * 3.6),
            timestamp: Date(),
            status:    .active
        )

        Task {
            let success = await OfflineQueueService.shared.insertOrQueue(
                table: "sos_alerts", payload: alert, payloadType: .sosAlert
            )
            if success {
                state       = .active
                sendFailed  = false
                alertStatus = .active
                sendLocalNotification(
                    title: "SOS Alert Sent",
                    body:  "Your fleet manager has been notified of your emergency."
                )
                startStatusPolling()
            } else {
                state      = .active
                sendFailed = true
                sendLocalNotification(
                    title: "SOS Alert Queued",
                    body:  "No network. Alert will be sent when connection is restored."
                )
            }
            startLocationPings()
        }
    }

    public func deactivateSOS() {
        pingTask?.cancel();       pingTask       = nil
        statusPollTask?.cancel(); statusPollTask = nil
        pingCount   = 0
        sosAlertId  = nil
        alertStatus = .active
        endBackgroundTask()
        state = .idle
    }

    public func cancelSOS() {
        guard let alertId = sosAlertId else { deactivateSOS(); return }
        Task {
            do {
                try await SupabaseService.shared.client
                    .from("sos_alerts")
                    .update(["status": SOSAlertStatus.cancelled.rawValue])
                    .eq("id", value: alertId)
                    .execute()
                deactivateSOS()
            } catch {
                #if DEBUG
                print("[SOSViewModel] cancelSOS error: \(error)")
                #endif
                
                self.errorMessage = "Failed to cancel SOS alert. Please try again or contact dispatch directly."
                self.showError = true
                
                // Fallback to deactivate locally anyway to clear the screen
                deactivateSOS()
            }
        }
    }

    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate        = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.requestWhenInUseAuthorization()
        locationManager?.startUpdatingLocation()
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in self.currentLocation = location }
    }

    private func startLocationPings() {
        pingCount = 0
        pingTask?.cancel()
        sendLocationPing()

        pingTask = Task { @MainActor [weak self] in
            while let self = self {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                if Task.isCancelled { break }
                
                self.pingCount += 1
                self.sendLocationPing()

                if self.pingCount >= 30 {
                    break // exit 10 sec loop to switch logic
                }
            }
            
            guard let self = self, !Task.isCancelled else { return }
            
            self.pingTask = Task { @MainActor [weak self] in
                while let self = self {
                    try? await Task.sleep(nanoseconds: 30_000_000_000)
                    if Task.isCancelled { break }
                    self.sendLocationPing()
                }
            }
        }
    }

    private func sendLocationPing() {
        guard let location = currentLocation ?? locationManager?.location else { return }
        currentLocation = location

        let ping = SOSLocationPing(
            sosAlertId: sosAlertId,
            driverId:   driverId,
            latitude:   location.coordinate.latitude,
            longitude:  location.coordinate.longitude,
            speed:      max(0, location.speed * 3.6),
            timestamp:  Date()
        )
        Task {
            _ = await OfflineQueueService.shared.insertOrQueue(
                table: "sos_location_pings", payload: ping, payloadType: .sosAlert
            )
        }
    }

    private func beginBackgroundTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }

    private func startStatusPolling() {
        statusPollTask?.cancel()
        
        statusPollTask = Task { @MainActor [weak self] in
            while let self = self {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if Task.isCancelled { break }
                
                guard let alertId = self.sosAlertId else { break }
                self.pollAlertStatus(alertId: alertId)
            }
        }
    }

    private func pollAlertStatus(alertId: String) {
        Task {
            do {
                let response = try await SupabaseService.shared.client
                    .from("sos_alerts").select().eq("id", value: alertId).single().execute()
                let alert          = try JSONDecoder.supabase().decode(SOSAlert.self, from: response.data)
                let previousStatus = alertStatus
                alertStatus        = alert.status

                if alert.status == .acknowledged && previousStatus == .active {
                    sendLocalNotification(
                        title: "Fleet Manager Aware",
                        body:  "Your fleet manager has acknowledged your emergency."
                    )
                }
                if alert.status == .resolved {
                    sendLocalNotification(
                        title: "SOS Resolved",
                        body:  "Your fleet manager has resolved the emergency alert."
                    )
                    statusPollTask?.cancel()
                    statusPollTask = nil
                }
            } catch {
                #if DEBUG
                print("[SOSViewModel] pollAlertStatus error: \(error)")
                #endif
            }
        }
    }

    private func sendLocalNotification(title: String, body: String) {
        let content   = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default
        let request   = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

public struct SOSLocationPing: Codable {
    public var sosAlertId: String?
    public var driverId:   String
    public var latitude:   Double
    public var longitude:  Double
    public var speed:      Double
    public var timestamp:  Date

    enum CodingKeys: String, CodingKey {
        case sosAlertId = "sos_alert_id"
        case driverId   = "driver_id"
        case latitude
        case longitude
        case speed
        case timestamp
    }
}
