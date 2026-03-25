import Foundation
import Observation
import Supabase

@Observable
@MainActor
public final class FuelDeviationAlertsViewModel {

    private actor DeviationRunGate {
        private var isRunning = false

        func beginIfIdle() -> Bool {
            guard !isRunning else { return false }
            isRunning = true
            return true
        }

        func end() {
            isRunning = false
        }
    }

    private struct TripRow: Decodable {
        let vehicleId: String?
        let distanceKm: Double?
        let fuelUsedLiters: Double?
        let startTime: Date?

        enum CodingKeys: String, CodingKey {
            case vehicleId = "vehicle_id"
            case distanceKm = "distance_km"
            case fuelUsedLiters = "fuel_used_liters"
            case startTime = "start_time"
        }
    }

    private struct VehicleRow: Decodable {
        let id: String
        let plateNumber: String

        enum CodingKeys: String, CodingKey {
            case id
            case plateNumber = "plate_number"
        }
    }

    public var alerts: [FuelDeviationAlert] = []
    public var isLoading = false
    public var errorMessage: String?
    public var thresholdPercent: Double = 15

    private var pollingTimer: Timer?
    private let deviationRunGate = DeviationRunGate()

    private struct AlertStatusUpdatePayload: Encodable {
        let status: String
    }

    public init() {}

    public func startPolling() {
        pollingTimer?.invalidate()
        Task { await runDeviationCheck() }
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.runDeviationCheck()
            }
        }
    }

    public func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    public func runDeviationCheck() async {
        guard await deviationRunGate.beginIfIdle() else { return }

        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            Task { await deviationRunGate.end() }
        }

        do {
            let now = Date()
            guard
                let lookbackStart = Calendar.current.date(byAdding: .day, value: -60, to: now),
                let currentWindowStart = Calendar.current.date(byAdding: .day, value: -7, to: now),
                let baselineWindowStart = Calendar.current.date(byAdding: .day, value: -37, to: now)
            else {
                return
            }

            let iso = ISO8601DateFormatter()
            let from = iso.string(from: lookbackStart)
            let to = iso.string(from: now)

            async let tripsTask: [TripRow] = SupabaseService.shared.client
                .from("trips")
                .select("vehicle_id, distance_km, fuel_used_liters, start_time")
                .gte("start_time", value: from)
                .lte("start_time", value: to)
                .execute().value

            async let vehiclesTask: [VehicleRow] = SupabaseService.shared.client
                .from("vehicles")
                .select("id, plate_number")
                .execute().value

            let (tripRows, vehicles) = try await (tripsTask, vehiclesTask)
            let labelByVehicle = Dictionary(uniqueKeysWithValues: vehicles.map { ($0.id, $0.plateNumber) })

            typealias Agg = (distance: Double, fuel: Double)
            var currentAgg: [String: Agg] = [:]
            var baselineAgg: [String: Agg] = [:]

            for row in tripRows {
                guard
                    let vehicleId = row.vehicleId,
                    let distance = row.distanceKm,
                    let fuel = row.fuelUsedLiters,
                    fuel > 0,
                    let date = row.startTime
                else {
                    continue
                }

                if date >= currentWindowStart {
                    let old = currentAgg[vehicleId] ?? (0, 0)
                    currentAgg[vehicleId] = (old.distance + distance, old.fuel + fuel)
                } else if date >= baselineWindowStart && date < currentWindowStart {
                    let old = baselineAgg[vehicleId] ?? (0, 0)
                    baselineAgg[vehicleId] = (old.distance + distance, old.fuel + fuel)
                }
            }

            var nextAlerts: [FuelDeviationAlert] = []
            for (vehicleId, current) in currentAgg {
                guard let baseline = baselineAgg[vehicleId], baseline.fuel > 0 else { continue }

                let currentRate = current.distance / current.fuel
                let baselineRate = baseline.distance / baseline.fuel
                guard baselineRate > 0 else { continue }

                let deviation = ((currentRate - baselineRate) / baselineRate) * 100
                if abs(deviation) >= thresholdPercent {
                    let existingStatus = alerts.first(where: { $0.vehicleId == vehicleId })?.status ?? .active
                    nextAlerts.append(
                        FuelDeviationAlert(
                            id: vehicleId,
                            vehicleId: vehicleId,
                            vehicleLabel: labelByVehicle[vehicleId] ?? vehicleId,
                            currentRate: currentRate,
                            baselineRate: baselineRate,
                            deviationPercent: deviation,
                            timestamp: now,
                            status: existingStatus
                        )
                    )
                }
            }

            alerts = nextAlerts.sorted { $0.timestamp > $1.timestamp }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func updateStatus(alertId: String, status: FuelDeviationAlertStatus) async {
        guard let index = alerts.firstIndex(where: { $0.id == alertId }) else { return }

        let previousStatus = alerts[index].status
        alerts[index].status = status

        do {
            try await SupabaseService.shared.client
                .from("fuel_deviation_alerts")
                .update(AlertStatusUpdatePayload(status: status.rawValue))
                .eq("id", value: alertId)
                .execute()
            errorMessage = nil
        } catch {
            alerts[index].status = previousStatus
            errorMessage = "Failed to update alert status. Please try again."
        }
    }
}
