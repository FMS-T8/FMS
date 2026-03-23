import Foundation
import CoreMotion
import Observation

@MainActor
@Observable
public final class CrashDetectionService {
    public static let shared = CrashDetectionService()

    // MARK: - Configuration

    private let impactThresholdG: Double = 4.0
    private let sustainedImpactWindow: TimeInterval = 0.3
    private let sustainedSampleCount = 3
    private let updateInterval: TimeInterval = 0.05

    // MARK: - State

    public var isMonitoring: Bool = false
    public var lastImpactDetected: Date?
    public var impactDetected: Bool = false

    // MARK: - Private

    private let motionManager = CMMotionManager()
    private let motionQueue = OperationQueue()
    private var recentHighGSamples: [Date] = []

    private init() {
        motionQueue.name = "com.fms.crashdetection"
        motionQueue.maxConcurrentOperationCount = 1
        motionQueue.qualityOfService = .userInteractive
    }

    // MARK: - Public API

    public func startMonitoring() {
        guard !isMonitoring else { return }
        guard motionManager.isAccelerometerAvailable else { return }

        isMonitoring = true
        recentHighGSamples = []
        motionManager.accelerometerUpdateInterval = updateInterval

        motionManager.startAccelerometerUpdates(to: motionQueue) { [weak self] data, _ in
            guard let self, let data else { return }
            self.processOnBackgroundQueue(data)
        }
    }

    public func stopMonitoring() {
        motionManager.stopAccelerometerUpdates()
        isMonitoring = false
        recentHighGSamples = []
    }

    public func triggerManualSOS() {
        impactDetected = true
        lastImpactDetected = Date()
    }

    public func clearImpact() {
        impactDetected = false
        recentHighGSamples = []
    }

    // MARK: - Private — runs on motionQueue (background)

    private nonisolated func processOnBackgroundQueue(_ data: CMAccelerometerData) {
        let x = data.acceleration.x
        let y = data.acceleration.y
        let z = data.acceleration.z
        let totalG = sqrt(x * x + y * y + z * z)

        guard totalG >= impactThresholdG else { return }

        let now = Date()

        Task { @MainActor [weak self] in
            guard let self, !self.impactDetected else { return }

            // Prune samples outside the sustained window
            self.recentHighGSamples.append(now)
            self.recentHighGSamples.removeAll { now.timeIntervalSince($0) > self.sustainedImpactWindow }

            // Require multiple high-G samples within the window to confirm impact
            if self.recentHighGSamples.count >= self.sustainedSampleCount {
                self.impactDetected = true
                self.lastImpactDetected = now
                self.recentHighGSamples = []
            }
        }
    }
}
