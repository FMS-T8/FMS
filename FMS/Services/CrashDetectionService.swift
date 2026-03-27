import Foundation
import CoreMotion
import Observation

@MainActor
@Observable
public final class CrashDetectionService {
    public static let shared = CrashDetectionService()

    // MARK: - Configuration
    private let impactThresholdG: Double = 3.0       // Lower threshold since gravity is now removed
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
        // Prefer deviceMotion (gives userAcceleration = gravity removed)
        // Fall back to raw accelerometer if unavailable
        guard motionManager.isDeviceMotionAvailable || motionManager.isAccelerometerAvailable else { return }

        isMonitoring = true
        recentHighGSamples = []
        motionManager.deviceMotionUpdateInterval = updateInterval
        motionManager.accelerometerUpdateInterval = updateInterval

        if motionManager.isDeviceMotionAvailable {
            motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] data, _ in
                guard let self, let data else { return }
                // userAcceleration is gravity-free, in g-units
                let u = data.userAcceleration
                let totalG = sqrt(u.x * u.x + u.y * u.y + u.z * u.z)
                self.processSample(totalG: totalG)
            }
        } else {
            // Fallback: raw accelerometer includes ~1g gravity at rest
            motionManager.startAccelerometerUpdates(to: motionQueue) { [weak self] data, _ in
                guard let self, let data else { return }
                let a = data.acceleration
                let totalG = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
                // Subtract 1g baseline since gravity is included
                let motionG = max(0, totalG - 1.0)
                self.processSample(totalG: motionG)
            }
        }
    }

    public func stopMonitoring() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.stopDeviceMotionUpdates()
        } else {
            motionManager.stopAccelerometerUpdates()
        }
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
    private nonisolated func processSample(totalG: Double) {
        guard totalG >= impactThresholdG else { return }

        let now = Date()
        Task { @MainActor [weak self] in
            guard let self, !self.impactDetected else { return }

            // Prune stale samples BEFORE appending (bug fix)
            self.recentHighGSamples.removeAll { now.timeIntervalSince($0) > self.sustainedImpactWindow }
            self.recentHighGSamples.append(now)

            if self.recentHighGSamples.count >= self.sustainedSampleCount {
                self.impactDetected = true
                self.lastImpactDetected = now
                self.recentHighGSamples = []
            }
        }
    }
}