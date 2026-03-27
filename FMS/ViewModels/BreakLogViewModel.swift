import Foundation
import CoreLocation
import Observation
import Supabase


@MainActor
@Observable
public final class BreakLogViewModel: NSObject, CLLocationManagerDelegate {

    // MARK: - State

    public var isOnBreak: Bool = false
    public var selectedBreakType: BreakType = .rest
    public var notes: String = ""
    public var currentBreakStartTime: Date?
    public var currentBreakElapsedSeconds: TimeInterval = 0
    public var currentBreakId: String?
    public var breakLogs: [BreakLog] = []
    public var showMinDurationWarning: Bool = false
    public var errorMessage: String? = nil
    private var isSubmitting: Bool = false

    // MARK: - Identity

    public var driverId: String
    public var tripId: String
    public var vehicleId: String
    private var timer: Timer?
    private var locationManager: CLLocationManager?
    private var startLocation: CLLocation?
    private var currentLocation: CLLocation?

    private let minimumBreakSeconds: TimeInterval = 5 * 60

    // MARK: - Init

    public init(driverId: String, tripId: String, vehicleId: String) {
        self.driverId = driverId
        self.tripId = tripId
        self.vehicleId = vehicleId
        super.init()
        setupLocationManager()
    }

    // Default init for compatibility with standard declarations where values are not yet known
    public override init() {
        self.driverId = ""
        self.tripId = ""
        self.vehicleId = ""
        super.init()
        setupLocationManager()
    }

    // MARK: - Formatted

    public var formattedElapsed: String {
        let total = Int(currentBreakElapsedSeconds)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Public API

    public func startBreak(driverId: String? = nil, tripId: String? = nil, lat: Double? = nil, lng: Double? = nil) {
        guard !isOnBreak && !isSubmitting else { return }
        isSubmitting = true
        
        if let dId = driverId { self.driverId = dId }
        if let tId = tripId { self.tripId = tId }
        
        isOnBreak = true
        let start = Date()
        currentBreakStartTime = start
        currentBreakElapsedSeconds = 0
        currentBreakId = UUID().uuidString
        showMinDurationWarning = false
        locationManager?.requestLocation()
        startLocation = currentLocation ?? locationManager?.location

        // Push outgoing break immediately as an offline insert payload
        let initialLog = BreakLog(
            id: currentBreakId!,
            tripId: self.tripId.isEmpty ? nil : self.tripId,
            driverId: self.driverId.isEmpty ? nil : self.driverId,
            breakType: selectedBreakType.rawValue,
            startTime: start,
            endTime: nil,
            durationMinutes: nil,
            lat: startLocation?.coordinate.latitude ?? lat,
            lng: startLocation?.coordinate.longitude ?? lng,
            endLat: nil,
            endLng: nil,
            notes: notes.isEmpty ? nil : notes
        )
        Task {
            await saveBreakLog(initialLog)
            isSubmitting = false
        }

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.currentBreakStartTime else { return }
                self.currentBreakElapsedSeconds = Date().timeIntervalSince(start)
            }
        }
    }

    public func endBreak(lat: Double? = nil, lng: Double? = nil) {
        guard isOnBreak && !isSubmitting, let startTime = currentBreakStartTime else { return }
        isSubmitting = true
        timer?.invalidate()
        timer = nil
        isOnBreak = false

        locationManager?.requestLocation()
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let durationMinutes = Int(duration / 60)
        let endLocation = currentLocation ?? locationManager?.location

        if duration < minimumBreakSeconds {
            showMinDurationWarning = true
        }

        let log = BreakLog(
            id: currentBreakId ?? UUID().uuidString,
            tripId: self.tripId.isEmpty ? nil : self.tripId,
            driverId: self.driverId.isEmpty ? nil : self.driverId,
            breakType: selectedBreakType.rawValue,
            startTime: startTime,
            endTime: endTime,
            durationMinutes: max(1, durationMinutes),
            lat: startLocation?.coordinate.latitude,
            lng: startLocation?.coordinate.longitude,
            endLat: endLocation?.coordinate.latitude ?? lat,
            endLng: endLocation?.coordinate.longitude ?? lng,
            notes: notes.isEmpty ? nil : notes
        )

        breakLogs.removeAll(where: { $0.id == log.id })
        breakLogs.insert(log, at: 0)
        currentBreakStartTime = nil
        currentBreakId = nil
        currentBreakElapsedSeconds = 0
        notes = ""

        Task {
            await saveBreakLog(log, isUpdate: true)
            isSubmitting = false
        }
    }

    // MARK: - Fetch History

    public func fetchBreakHistory() async {
        do {
            guard !tripId.isEmpty else { return }
            let response = try await SupabaseService.shared.client
                .from("break_logs")
                .select()
                .eq("trip_id", value: tripId)
                .order("start_time", ascending: false)
                .limit(50)
                .execute()

            let fetched = try JSONDecoder.supabase().decode([BreakLog].self, from: response.data)

            // Merge: keep locally-logged breaks, add any from DB not already present
            let localIds = Set(breakLogs.map(\.id))
            let newFromDB = fetched.filter { !localIds.contains($0.id) }
            breakLogs = (breakLogs + newFromDB).sorted {
                ($0.startTime ?? .distantPast) > ($1.startTime ?? .distantPast)
            }
        } catch {
            print("[BreakLogViewModel] Failed to load breaks (silent fallback): \(error)")
            self.errorMessage = "Failed to fetch break history: \(error.localizedDescription)"
        }
    }
    
    /// Loads breaks by driver across trips (Crash Recovery endpoint).
    /// If a `tripId` is provided, the break is only restored if it matches that trip.
    public func loadBreaks(driverId: String, tripId: String? = nil) async {
        do {
            let response = try await SupabaseService.shared.client
                .from("break_logs")
                .select()
                .eq("driver_id", value: driverId)
                .order("start_time", ascending: false)
                .limit(50)
                .execute()

            let breaks = try JSONDecoder.supabase().decode([BreakLog].self, from: response.data)
            self.breakLogs = breaks.filter { !$0.isOngoing }
            
            if let openBreak = breaks.first(where: { $0.isOngoing }) {
                // Determine if we should restore this break
                // 1. If tripId is provided, it MUST match.
                // 2. If tripId is NOT provided, we only restore if the break itself has no tripId (rare)
                //    or if we just want to restore whatever the driver's last state was.
                // 3. For the dashboard, we usually pass the active tripId.
                let shouldRestore: Bool = {
                    if let currentTripId = tripId {
                        return openBreak.tripId == currentTripId
                    }
                    // If no current trip context, we might still want to restore a general break
                    // But for this bug, we'll be strict: only restore if it was a general break
                    // or if we're not scoping to a trip.
                    return openBreak.tripId == nil
                }()

                if shouldRestore {
                    self.isOnBreak = true
                    self.currentBreakStartTime = openBreak.startTime
                    self.currentBreakId = openBreak.id
                    if let tId = openBreak.tripId { self.tripId = tId }
                    
                    if let storedType = openBreak.breakType, let breakType = BreakType(rawValue: storedType) {
                        self.selectedBreakType = breakType
                    } else {
                        self.selectedBreakType = .rest
                    }
                    
                    timer?.invalidate()
                    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                        Task { @MainActor [weak self] in
                            guard let self, let start = self.currentBreakStartTime else { return }
                            self.currentBreakElapsedSeconds = Date().timeIntervalSince(start)
                        }
                    }
                } else {
                    // It's an ongoing break for a DIFFERENT trip or context.
                    // We should NOT show it as active for the current context.
                    self.isOnBreak = false
                }
            } else {
                // Server confirms no ongoing break — clear any stale local state
                if isOnBreak {
                    timer?.invalidate()
                    timer = nil
                    isOnBreak = false
                    currentBreakStartTime = nil
                    currentBreakId = nil
                    currentBreakElapsedSeconds = 0
                    selectedBreakType = .rest
                }
            }
        } catch {
            print("⚠️ [BreakLogViewModel] Failed to load driver breaks: \(error)")
            self.errorMessage = "Failed to load breaks: \(error.localizedDescription)"
        }
    }

    // MARK: - Persistence

    private func saveBreakLog(_ log: BreakLog, isUpdate: Bool = false) async {
        if isUpdate {
            struct BreakLogUpdate: Codable {
                let end_time: Date?
                let duration_minutes: Int?
                let notes: String?
            }
            let updatePayload = BreakLogUpdate(
                end_time: log.endTime,
                duration_minutes: log.durationMinutes,
                notes: log.notes
            )
            _ = await OfflineQueueService.shared.updateOrQueue(
                table: "break_logs",
                payload: updatePayload,
                id: log.id,
                payloadType: .breakLog
            )
        } else {
            let insert = BreakLogInsert(
                id: log.id,
                tripId: log.tripId,
                driverId: log.driverId,
                breakType: log.breakType,
                startTime: log.startTime,
                endTime: log.endTime,
                durationMinutes: log.durationMinutes,
                lat: log.lat,
                lng: log.lng,
                notes: log.notes
            )
            
            _ = await OfflineQueueService.shared.insertOrQueue(
                table: "break_logs",
                payload: insert,
                payloadType: .breakLog
            )
        }
    }

    // MARK: - Location

    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.requestWhenInUseAuthorization()
    }

    /// Stop location updates and clean up resources.
    public func stopLocationUpdates() {
        locationManager?.stopUpdatingLocation()
        locationManager?.delegate = nil
        locationManager = nil
    }

    // CLLocationManagerDelegate
    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Best-effort location — break log will use nil coordinates
    }
}
