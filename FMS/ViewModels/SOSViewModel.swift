import Foundation
import CoreLocation
import Observation
import UserNotifications
import Supabase
import UIKit

@MainActor
@Observable
public final class SOSViewModel: NSObject, CLLocationManagerDelegate {

    // MARK: - State

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

    /// Tracks fleet manager acknowledgment/resolution
    public var alertStatus: SOSAlertStatus = .active
    public var isAcknowledged: Bool { alertStatus == .acknowledged }
    public var isResolved: Bool { alertStatus == .resolved }

    // MARK: - Configuration

    private let countdownDuration = 10

    // MARK: - Private

    private var countdownTargetDate: Date?
    private var countdownTimer: Timer?
    private var locationManager: CLLocationManager?
    private var currentLocation: CLLocation?
    private var pingTimer: Timer?
    private var pingCount = 0
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var sosAlertId: String?
    private var statusPollTimer: Timer?

    private let driverId: String
    private let vehicleId: String
    private let tripId: String?

    // MARK: - Init

    public init(driverId: String, vehicleId: String, tripId: String? = nil) {
        self.driverId = driverId
        self.vehicleId = vehicleId
        self.tripId = tripId
        super.init()
        setupLocationManager()
    }

    // MARK: - Public API

    public func startCountdown() {
        guard case .idle = state else { return }
        let target = Date().addingTimeInterval(TimeInterval(countdownDuration))
        countdownTargetDate = target
        state = .countdown(secondsRemaining: countdownDuration)

        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self, let target = self.countdownTargetDate else {
                    timer.invalidate()
                    return
                }
                let remaining = Int(ceil(target.timeIntervalSinceNow))
                if remaining <= 0 {
                    timer.invalidate()
                    self.sendSOS()
                } else {
                    self.state = .countdown(secondsRemaining: remaining)
                }
            }
        }
    }

    public func cancelCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownTargetDate = nil
        state = .idle
    }

    public func sendSOS() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownTargetDate = nil
        state = .sending
        sendFailed = false

        beginBackgroundTask()

        let lat = currentLocation?.coordinate.latitude ?? 0
        let lng = currentLocation?.coordinate.longitude ?? 0
        let speed = currentLocation?.speed ?? 0

        let alertId = UUID().uuidString
        sosAlertId = alertId

        let alert = SOSAlertInsert(
            driverId: driverId,
            vehicleId: vehicleId,
            tripId: tripId,
            latitude: lat,
            longitude: lng,
            speed: max(0, speed * 3.6),
            timestamp: Date(),
            status: "active"
        )

        Task {
            let success = await OfflineQueueService.shared.insertOrQueue(
                table: "sos_alerts",
                payload: alert,
                payloadType: .sosAlert
            )

            if success {
                state = .active
                sendFailed = false
                alertStatus = .active
                sendLocalNotification(
                    title: "SOS Alert Sent",
                    body: "Your fleet manager has been notified of your emergency."
                )
                startStatusPolling()
            } else {
                state = .active
                sendFailed = true
                sendLocalNotification(
                    title: "SOS Alert Queued",
                    body: "No network. Alert will be sent when connection is restored."
                )
            }

            startLocationPings()
        }
    }

    public func deactivateSOS() {
        pingTimer?.invalidate()
        pingTimer = nil
        statusPollTimer?.invalidate()
        statusPollTimer = nil
        pingCount = 0
        sosAlertId = nil
        alertStatus = .active
        endBackgroundTask()
        state = .idle
    }

    /// Driver cancels own SOS — updates status to cancelled in Supabase.
    public func cancelSOS() {
        guard let alertId = sosAlertId else {
            deactivateSOS()
            return
        }

        Task {
            do {
                try await SupabaseService.shared.client
                    .from("sos_alerts")
                    .update(["status": SOSAlertStatus.cancelled.rawValue])
                    .eq("id", value: alertId)
                    .execute()
            } catch {
                // Best-effort
            }
            deactivateSOS()
        }
    }

    // MARK: - Location

    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.requestWhenInUseAuthorization()
        locationManager?.startUpdatingLocation()
    }

    // CLLocationManagerDelegate
    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location
        }
    }

    private func startLocationPings() {
        pingCount = 0
        pingTimer?.invalidate()

        // First ping immediately
        sendLocationPing()

        pingTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self else { timer.invalidate(); return }
                self.pingCount += 1
                self.sendLocationPing()

                // After 5 minutes (30 pings at 10s), switch to 30s interval
                if self.pingCount >= 30 {
                    timer.invalidate()
                    self.pingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] t in
                        Task { @MainActor [weak self] in
                            guard let self else { t.invalidate(); return }
                            self.sendLocationPing()
                        }
                    }
                }
            }
        }
    }

    private func sendLocationPing() {
        guard let location = currentLocation ?? locationManager?.location else { return }
        currentLocation = location

        let ping = SOSLocationPing(
            sosAlertId: sosAlertId,
            driverId: driverId,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            speed: max(0, location.speed * 3.6),
            timestamp: Date()
        )

        Task {
            _ = await OfflineQueueService.shared.insertOrQueue(
                table: "sos_location_pings",
                payload: ping,
                payloadType: .sosAlert
            )
        }
    }

    // MARK: - Background Task

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

    // MARK: - Status Polling

    private func startStatusPolling() {
        statusPollTimer?.invalidate()
        statusPollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self, let alertId = self.sosAlertId else {
                    timer.invalidate()
                    return
                }
                self.pollAlertStatus(alertId: alertId)
            }
        }
    }

    private func pollAlertStatus(alertId: String) {
        Task {
            do {
                let response = try await SupabaseService.shared.client
                    .from("sos_alerts")
                    .select()
                    .eq("id", value: alertId)
                    .single()
                    .execute()

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let alert = try decoder.decode(SOSAlert.self, from: response.data)

                let previousStatus = alertStatus
                alertStatus = alert.status

                if alert.status == .acknowledged && previousStatus == .active {
                    sendLocalNotification(
                        title: "Fleet Manager Aware",
                        body: "Your fleet manager has acknowledged your emergency."
                    )
                }

                if alert.status == .resolved {
                    sendLocalNotification(
                        title: "SOS Resolved",
                        body: "Your fleet manager has resolved the emergency alert."
                    )
                    statusPollTimer?.invalidate()
                    statusPollTimer = nil
                }
            } catch {
                // Will retry on next poll
            }
        }
    }

    // MARK: - Notifications

    private func sendLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - SOS Location Ping Model

public struct SOSLocationPing: Codable {
    public var sosAlertId: String?
    public var driverId: String
    public var latitude: Double
    public var longitude: Double
    public var speed: Double
    public var timestamp: Date

    enum CodingKeys: String, CodingKey {
        case sosAlertId = "sos_alert_id"
        case driverId = "driver_id"
        case latitude
        case longitude
        case speed
        case timestamp
    }
}
