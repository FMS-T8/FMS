import Foundation
import CoreLocation
import Supabase
import PostgREST
import Observation

public func isInsideGeofence(current: CLLocation, target: CLLocation, radius: Double) -> Bool {
    current.distance(from: target) <= radius
}

@MainActor
@Observable
public final class TripExecutionViewModel {
    public let geofenceRadius: Double = 1000

    public private(set) var currentPhase: TripPhase = .pickup
    public private(set) var startTime: Date?
    public private(set) var endTime: Date?
    public private(set) var hasStartedTrip = false
    public private(set) var hasEndedTrip = false
    public private(set) var isBreakActive = false
    public private(set) var samplesReadyForSync: [TripLocationSample] = []

    public private(set) var pickupDistanceMeters: Double?
    public private(set) var destinationDistanceMeters: Double?
    public private(set) var insidePickupGeofence = false
    public private(set) var insideDestinationGeofence = false

    private let tripId: String
    private let pickupLocation: CLLocation?
    private let destinationLocation: CLLocation?

    private weak var locationManager: LocationManager?
    private var samplingTimer: Timer?
    private var syncTimer: Timer?

    private let maxBatchSize = 50
    private var syncRetryCount = 0
    private var isSyncing = false
    private var syncRetryTask: Task<Void, Never>?
    private var locationUpdatesTask: Task<Void, Never>?

    // Hysteresis counters to avoid rapid toggling on GPS drift.
    private var pickupInsideHits = 0
    private var pickupOutsideHits = 0
    private var destinationInsideHits = 0
    private var destinationOutsideHits = 0
    private let requiredStableHits = 2

    public init(
        tripId: String,
        pickupCoordinate: CLLocationCoordinate2D?,
        destinationCoordinate: CLLocationCoordinate2D?
    ) {
        self.tripId = tripId
        if let pickup = pickupCoordinate {
            self.pickupLocation = CLLocation(latitude: pickup.latitude, longitude: pickup.longitude)
        } else {
            self.pickupLocation = nil
        }
        
        if let destination = destinationCoordinate {
            self.destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        } else {
            self.destinationLocation = nil
        }
    }

    public func attachLocationManager(_ manager: LocationManager) {
        locationManager = manager
        print("[TripExecution] Attached LocationManager for trip \(tripId)")
        observeLocationUpdates()
    }

    public func detachLocationManager() {
        locationUpdatesTask?.cancel()
        locationUpdatesTask = nil
        print("[TripExecution] Detached LocationManager for trip \(tripId)")
    }

    deinit {
        // Task will break automatically when self is deallocated due to [weak self] loop guard.
    }

    private func observeLocationUpdates() {
        locationUpdatesTask?.cancel()
        locationUpdatesTask = Task { [weak self] in
            guard let updates = self?.locationManager?.locationUpdates() else { return }
            for await location in updates {
                if Task.isCancelled { break }
                guard let self = self else { break }
                self.consume(location: location)
            }
        }
    }

    public var hasLocationPermission: Bool {
        locationManager?.isAuthorizedForTrip == true
    }

    public var canStartTrip: Bool {
        guard let _ = pickupLocation else { return false }
        return hasLocationPermission && !hasStartedTrip && insidePickupGeofence
    }

    public var canEndTrip: Bool {
        guard let _ = destinationLocation else { return false }
        return hasLocationPermission && hasStartedTrip && !hasEndedTrip && insideDestinationGeofence
    }

    public func requestPermissionsAndTracking() {
        locationManager?.requestAlwaysPermission()
        locationManager?.startUpdating()
    }

    public func configureInitialState(status: String?, startTime: Date?, endTime: Date?) {
        let normalized = status?.lowercased()
        if normalized == "active" {
            hasStartedTrip = true
            hasEndedTrip = false
            currentPhase = isBreakActive ? .inBreak : .inTransit
            self.startTime = startTime ?? self.startTime
            beginSamplingIfNeeded()
            print("[TripExecution] Configured as active trip \(tripId)")
            return
        }

        if normalized == "completed" || normalized == "delivered" {
            hasStartedTrip = true
            hasEndedTrip = true
            currentPhase = .delivery
            self.startTime = startTime ?? self.startTime
            self.endTime = endTime ?? self.endTime
            stopTracking()
        }
    }

    public func stopTracking() {
        samplingTimer?.invalidate()
        samplingTimer = nil
        syncTimer?.invalidate()
        syncTimer = nil
        syncRetryTask?.cancel()
        syncRetryTask = nil
        detachLocationManager()
        print("[TripExecution] Stopped location tracking for trip \(tripId)")
    }

    public func startTrip() {
        guard canStartTrip else {
            print("[TripExecution] Cannot start trip \(tripId) — canStartTrip=false (perm=\(hasLocationPermission), started=\(hasStartedTrip), inGeofence=\(insidePickupGeofence))")
            return
        }
        hasStartedTrip = true
        currentPhase = .inTransit
        startTime = Date()
        isBreakActive = false
        beginSamplingIfNeeded()
        print("[TripExecution] Trip \(tripId) started")
    }

    public func endTrip() {
        guard canEndTrip else { return }
        currentPhase = .delivery
        endTime = Date()
        isBreakActive = false
        captureImmediateSample()
        hasEndedTrip = true
        print("[TripExecution] Trip \(tripId) ended")
        stopTracking()
    }

    public func takeBreak() {
        guard hasStartedTrip, !hasEndedTrip, !isBreakActive else { return }
        isBreakActive = true
        currentPhase = .inBreak
    }

    public func resumeTrip() {
        guard hasStartedTrip, !hasEndedTrip, isBreakActive else { return }
        isBreakActive = false
        currentPhase = .inTransit
    }

    private func beginSamplingIfNeeded() {
        guard samplingTimer == nil else { return }

        samplingTimer = Timer.scheduledTimer(withTimeInterval: 45, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.captureImmediateSample()
            }
        }
        captureImmediateSample()

        setupSyncTimer()
    }

    private func setupSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.syncSamplesToSupabase()
            }
        }
        RunLoop.main.add(syncTimer!, forMode: .common)
    }

    private func captureImmediateSample() {
        guard hasStartedTrip, !hasEndedTrip, let location = locationManager?.currentLocation else { return }
        let sample = TripLocationSample(
            tripId: tripId,
            phase: currentPhase,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: Date()
        )
        samplesReadyForSync.append(sample)
        
        Task { @MainActor in
            await syncSamplesToSupabase()
        }
    }

    public func syncSamplesToSupabase() async {
        guard !isSyncing, !samplesReadyForSync.isEmpty else { return }
        
        // Cancel any pending retry task if we're starting a fresh sync attempt
        syncRetryTask?.cancel()
        syncRetryTask = nil
        
        isSyncing = true
        
        let batch = Array(samplesReadyForSync.prefix(maxBatchSize))
        print("[TripSync] Attempting to sync batch of \(batch.count) samples for trip \(tripId)")
        
        do {
            try await SupabaseService.shared.client
                .from("trip_location_samples")
                .insert(batch)
                .execute()
            
            // On success: remove uploaded samples and reset retry count
            samplesReadyForSync.removeFirst(batch.count)
            syncRetryCount = 0
            isSyncing = false
            syncRetryTask?.cancel()
            syncRetryTask = nil
            
            print("[TripSync] Successfully synced \(batch.count) samples. Remaining in queue: \(samplesReadyForSync.count)")
            
            // If there's more data, trigger another sync immediately
            if !samplesReadyForSync.isEmpty {
                await syncSamplesToSupabase()
            }
        } catch {
            isSyncing = false
            syncRetryCount += 1
            let delay = min(Double(pow(2.0, Double(syncRetryCount))), 300.0) // Max 5 min delay
            print("[TripSync] Sync failed: \(error.localizedDescription). Retry count: \(syncRetryCount). Backing off for \(Int(delay))s")
            
            // Schedule retry with exponential backoff using a single Task token
            syncRetryTask?.cancel()
            syncRetryTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                if !Task.isCancelled {
                    await syncSamplesToSupabase()
                }
            }
        }
    }

    private func consume(location: CLLocation) {
        if let pickup = pickupLocation {
            let pickupDistance = location.distance(from: pickup)
            pickupDistanceMeters = pickupDistance
            
            updateSmoothedGeofence(
                distance: pickupDistance,
                insideCount: &pickupInsideHits,
                outsideCount: &pickupOutsideHits,
                output: &insidePickupGeofence
            )
        }

        if let destination = destinationLocation {
            let destinationDistance = location.distance(from: destination)
            destinationDistanceMeters = destinationDistance
                
            updateSmoothedGeofence(
                distance: destinationDistance,
                insideCount: &destinationInsideHits,
                outsideCount: &destinationOutsideHits,
                output: &insideDestinationGeofence
            )
        }
    }

    private func updateSmoothedGeofence(
        distance: Double,
        insideCount: inout Int,
        outsideCount: inout Int,
        output: inout Bool
    ) {
        let hysteresis: Double = 35

        if distance <= geofenceRadius {
            insideCount += 1
            outsideCount = 0
        } else if distance > geofenceRadius + hysteresis {
            outsideCount += 1
            insideCount = 0
        }

        if insideCount >= requiredStableHits {
            output = true
        }

        if outsideCount >= requiredStableHits {
            output = false
        }
    }
}
