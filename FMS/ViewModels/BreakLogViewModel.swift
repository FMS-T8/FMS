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
    public var currentBreakStartTime: Date?
    public var currentBreakElapsedSeconds: TimeInterval = 0
    public var breakLogs: [BreakLog] = []
    public var showMinDurationWarning: Bool = false

    // MARK: - Private

    private let driverId: String
    private let tripId: String
    private let vehicleId: String
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

    // MARK: - Formatted

    public var formattedElapsed: String {
        let total = Int(currentBreakElapsedSeconds)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Public API

    public func startBreak() {
        guard !isOnBreak else { return }
        isOnBreak = true
        currentBreakStartTime = Date()
        currentBreakElapsedSeconds = 0
        showMinDurationWarning = false
        startLocation = currentLocation ?? locationManager?.location

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.currentBreakStartTime else { return }
                self.currentBreakElapsedSeconds = Date().timeIntervalSince(start)
            }
        }
    }

    public func endBreak() {
        guard isOnBreak, let startTime = currentBreakStartTime else { return }
        timer?.invalidate()
        timer = nil
        isOnBreak = false

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let durationMinutes = Int(duration / 60)
        let endLocation = currentLocation ?? locationManager?.location

        if duration < minimumBreakSeconds {
            showMinDurationWarning = true
        }

        let log = BreakLog(
            id: UUID().uuidString,
            tripId: tripId,
            driverId: driverId,
            breakType: selectedBreakType.rawValue,
            startTime: startTime,
            endTime: endTime,
            durationMinutes: max(1, durationMinutes),
            lat: startLocation?.coordinate.latitude,
            lng: startLocation?.coordinate.longitude,
            endLat: endLocation?.coordinate.latitude,
            endLng: endLocation?.coordinate.longitude
        )

        breakLogs.append(log)
        currentBreakStartTime = nil
        currentBreakElapsedSeconds = 0

        Task {
            await saveBreakLog(log)
        }
    }

    // MARK: - Fetch History

    public func fetchBreakHistory() {
        Task {
            do {
                let response = try await SupabaseService.shared.client
                    .from("break_logs")
                    .select()
                    .eq("trip_id", value: tripId)
                    .order("start_time", ascending: false)
                    .execute()

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let fetched = try decoder.decode([BreakLog].self, from: response.data)

                // Merge: keep locally-logged breaks, add any from DB not already present
                let localIds = Set(breakLogs.map(\.id))
                let newFromDB = fetched.filter { !localIds.contains($0.id) }
                breakLogs = (breakLogs + newFromDB).sorted {
                    ($0.startTime ?? .distantPast) > ($1.startTime ?? .distantPast)
                }
            } catch {
                // Will show whatever is in memory
            }
        }
    }

    // MARK: - Persistence

    private func saveBreakLog(_ log: BreakLog) async {
        let insert = BreakLogInsert(
            tripId: log.tripId,
            driverId: log.driverId,
            breakType: log.breakType,
            startTime: log.startTime,
            endTime: log.endTime,
            durationMinutes: log.durationMinutes,
            lat: log.lat,
            lng: log.lng,
            endLat: log.endLat,
            endLng: log.endLng
        )

        _ = await OfflineQueueService.shared.insertOrQueue(
            table: "break_logs",
            payload: insert,
            payloadType: .breakLog
        )
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
}
