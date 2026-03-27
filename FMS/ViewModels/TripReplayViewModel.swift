import Foundation
import MapKit
import Observation
import Supabase

@Observable
@MainActor
public final class TripReplayViewModel {

    // MARK: - Data
    public var gpsPoints: [TripGPSLog] = []
    public var incidents: [Incident] = []
    public var breakLogs: [BreakLog] = []

    // MARK: - Loading State
    public var isLoading = false
    public var errorMessage: String? = nil

    // MARK: - Playback State
    /// The index into `gpsPoints` that is currently "showing".
    public var currentIndex: Int = 0
    public var isPlaying = false
    /// Multiplier: 1, 2, or 5.
    public var playbackSpeed: Double = 1.0

    // MARK: - Private
    private var playTimer: Timer? = nil
    private var livePollTimer: Timer? = nil
    private let livePollInterval: TimeInterval = 10.0
    private var activeTripId: String? = nil
    /// Base interval between frames (seconds) at 1×.
    private let baseFrameInterval: TimeInterval = 0.08
    
    public var currentFrameInterval: TimeInterval {
        baseFrameInterval / playbackSpeed
    }

    // MARK: - Computed

    public var totalPoints: Int { gpsPoints.count }

    public var currentPoint: TripGPSLog? {
        guard !gpsPoints.isEmpty, gpsPoints.indices.contains(currentIndex) else { return nil }
        return gpsPoints[currentIndex]
    }

    /// Elapsed time label (start → currentIndex).
    public var elapsedLabel: String {
        guard let first = gpsPoints.first?.recordedAt,
              let current = currentPoint?.recordedAt else { return "0:00" }
        return formatInterval(current.timeIntervalSince(first))
    }

    /// Total trip duration label.
    public var totalLabel: String {
        guard let first = gpsPoints.first?.recordedAt,
              let last = gpsPoints.last?.recordedAt else { return "0:00" }
        return formatInterval(last.timeIntervalSince(first))
    }

    /// Current speed in km/h if available.
    public var currentSpeedKph: Double? {
        currentPoint?.speed
    }

    /// Speed category for colour coding.
    public var speedCategory: SpeedCategory {
        guard let kph = currentSpeedKph else { return .normal }
        if kph > 90 { return .speeding }
        if kph > 60 { return .fast }
        return .normal
    }

    /// Polyline of points up to and including `currentIndex`.
    public var playedCoordinates: [CLLocationCoordinate2D] {
        guard !gpsPoints.isEmpty else { return [] }
        let clampedIndex = min(max(0, currentIndex), gpsPoints.count - 1)
        let slice = gpsPoints[0...clampedIndex]
        return slice.compactMap { point in
            guard let lat = point.lat, let lng = point.lng else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
    }

    /// All GPS coordinates (ghost path).
    public var allCoordinates: [CLLocationCoordinate2D] {
        gpsPoints.compactMap { point in
            guard let lat = point.lat, let lng = point.lng else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
    }

    public var hasData: Bool { !gpsPoints.isEmpty }

    // MARK: - Fetch

    public func load(trip: Trip) async {
        self.activeTripId = trip.id
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let gpsFetch: [TripGPSLog] = SupabaseService.shared.client
                .from("trip_gps_logs")
                .select()
                .eq("trip_id", value: trip.id)
                .order("recorded_at", ascending: true)
                .execute()
                .value

            async let incidentFetch: [Incident] = SupabaseService.shared.client
                .from("incidents")
                .select()
                .eq("trip_id", value: trip.id)
                .order("created_at", ascending: true)
                .execute()
                .value

            async let breakFetch: [BreakLog] = SupabaseService.shared.client
                .from("break_logs")
                .select()
                .eq("trip_id", value: trip.id)
                .order("start_time", ascending: true)
                .execute()
                .value

            let (gps, inc, brk) = try await (gpsFetch, incidentFetch, breakFetch)
            gpsPoints = gps
            incidents = inc
            breakLogs = brk
            
            let status = trip.status?.lowercased() ?? ""
            let isLive = status == "in_progress" || status == "ongoing" || status == "active" || status == "in_transit"
            if isLive {
                currentIndex = gpsPoints.isEmpty ? 0 : gpsPoints.count - 1
                startLivePolling()
            } else {
                currentIndex = 0
            }
        } catch {
            errorMessage = error.localizedDescription
            print("[TripReplayViewModel] ❌ Load failed: \(error)")
        }
    }

    // MARK: - Playback Control

    public func play() {
        guard !isPlaying, totalPoints > 1 else { return }
        isPlaying = true
        scheduleTimer()
    }

    public func pause() {
        isPlaying = false
        invalidateTimer()
    }

    public func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    public func reset() {
        pause()
        currentIndex = 0
    }

    public func seek(to index: Int) {
        guard totalPoints > 0 else {
            currentIndex = 0
            if isPlaying { pause() }
            return
        }
        let clamped = max(0, min(index, totalPoints - 1))
        currentIndex = clamped
        // If we were playing and reached end, stop.
        if clamped >= totalPoints - 1 { pause() }
    }

    public func setSpeed(_ speed: Double) {
        playbackSpeed = speed
        if isPlaying {
            invalidateTimer()
            scheduleTimer()
        }
    }

    // MARK: - Private Timer

    private func scheduleTimer() {
        invalidateTimer()
        let interval = baseFrameInterval / playbackSpeed
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.currentIndex < self.totalPoints - 1 {
                    self.currentIndex += 1
                } else {
                    self.pause()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        playTimer = timer
    }

    private func invalidateTimer() {
        playTimer?.invalidate()
        playTimer = nil
    }

    // MARK: - Live Polling (Active Trips)

    private func startLivePolling() {
        stopLivePolling()
        let timer = Timer(timeInterval: livePollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchNewPings()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        livePollTimer = timer
    }

    public func stopLivePolling() {
        livePollTimer?.invalidate()
        livePollTimer = nil
    }

    private func fetchNewPings() async {
        guard let tripId = activeTripId else { return }
        do {
            var query = SupabaseService.shared.client
                .from("trip_gps_logs")
                .select()
                .eq("trip_id", value: tripId)

            if let lastTime = gpsPoints.last?.recordedAt {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let dateStr = formatter.string(from: lastTime)
                query = query.gt("recorded_at", value: dateStr)
            }

            let newPings: [TripGPSLog] = try await query
                .order("recorded_at", ascending: true)
                .execute()
                .value

            guard !newPings.isEmpty else { return }

            print("[TripReplayViewModel] 📍 Polled \(newPings.count) new GPS pings.")
            let previousCount = gpsPoints.count
            let wasAtEnd = currentIndex == (previousCount - 1)
            gpsPoints.append(contentsOf: newPings)
            
            if wasAtEnd || previousCount == 0 {
                // Auto-advance to the latest point (live tracking behavior).
                seek(to: gpsPoints.count - 1)
            }
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == -999 { return }
            print("[TripReplayViewModel] Live poll failed: \(error)")
        }
    }

    // MARK: - Helpers

    private func formatInterval(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(max(0, interval))
        let hours = totalSeconds / 3600
        let mins = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        }
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Speed Category

public enum SpeedCategory {
    case normal, fast, speeding

    public var label: String {
        switch self {
        case .normal:   return "Normal"
        case .fast:     return "Fast"
        case .speeding: return "Speeding"
        }
    }
}
