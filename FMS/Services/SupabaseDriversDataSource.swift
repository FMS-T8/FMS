//
//  SupabaseDriversDataSource.swift
//  FMS
//

import Foundation
import Supabase

public final class SupabaseDriversDataSource: DriversDataSource {

  public init() {}

  public func fetchDrivers() async throws -> [DriverDisplayItem] {

    // MARK: 1. Fetch all active drivers
    struct UserRow: Decodable {
      let id: String
      let name: String
      let phone: String?
      let employee_id: String?
      let operational_status: String?
    }

    let usersResponse: [UserRow] = try await SupabaseService.shared.client
      .from("users")
      .select("id, name, phone, employee_id, operational_status")
      .eq("role", value: "driver")
      .eq("is_deleted", value: false)
      .eq("employment_status", value: "active")
      .execute()
      .value

    let driverIds = usersResponse.map(\.id)
    guard !driverIds.isEmpty else { return [] }

    // MARK: 2. Fetch vehicle assignments (joined with vehicles table)
    struct AssignmentRow: Decodable {
      let driver_id: String
      let vehicle_id: String?
      let vehicle: VehicleInfo?

      struct VehicleInfo: Decodable {
        let id: String
        let plate_number: String?
        let manufacturer: String?
        let model: String?
      }

      enum CodingKeys: String, CodingKey {
        case driver_id, vehicle_id
        case vehicle = "vehicles"
      }
    }

    let assignments: [AssignmentRow] =
      (try? await SupabaseService.shared.client
        .from("driver_vehicle_assignments")
        .select("driver_id, vehicle_id, vehicles(id, plate_number, manufacturer, model)")
        .in("driver_id", values: driverIds)
        .execute()
        .value) ?? []

    // Map driver_id → assignment for O(1) lookup
    let assignmentByDriverId = Dictionary(
      assignments.map { ($0.driver_id, $0) },
      uniquingKeysWith: { first, _ in first }
    )

    // MARK: 3. Fetch active/upcoming trips to populate activeTripId, shiftStart, shiftEnd
    struct TripRow: Decodable {
      let id: String
      let driver_id: String?
      let status: String?
      let start_time: Date?
      let end_time: Date?

      enum CodingKeys: String, CodingKey {
        case id
        case driver_id
        case status
        case start_time
        case end_time
      }
    }

    let activeStatuses = [
      "active", "in_progress", "in_transit", "scheduled", "assigned", "pending",
    ]
    let trips: [TripRow] =
      (try? await SupabaseService.shared.client
        .from("trips")
        .select("id, driver_id, status, start_time, end_time")
        .in("driver_id", values: driverIds)
        .in("status", values: activeStatuses)
        .order("start_time", ascending: true)
        .execute()
        .value) ?? []

    // Map driver_id → most relevant trip (prefer active over upcoming)
    var tripByDriverId: [String: TripRow] = [:]
    for trip in trips {
      guard let dId = trip.driver_id else { continue }
      if let existing = tripByDriverId[dId] {
        // Prefer truly active trips over scheduled ones
        let isNewActive = ["active", "in_progress", "in_transit"].contains(trip.status ?? "")
        let isExistingActive = ["active", "in_progress", "in_transit"].contains(
          existing.status ?? "")
        if isNewActive && !isExistingActive {
          tripByDriverId[dId] = trip
        }
      } else {
        tripByDriverId[dId] = trip
      }
    }

    // MARK: 4. Assemble DriverDisplayItems
    return usersResponse.map { user in
      let status: DriverAvailabilityStatus = {
        switch user.operational_status {
        case "on_trip": return .onTrip
        case "available": return .available
        default: return .offDuty
        }
      }()

      let assignment = assignmentByDriverId[user.id]
      let trip = tripByDriverId[user.id]

      return DriverDisplayItem(
        id: user.id,
        name: user.name,
        employeeID: user.employee_id ?? "EMP-\(user.id.prefix(6).uppercased())",
        phone: Self.normalizePhone(user.phone),
        vehicleId: assignment?.vehicle_id,
        vehicleManufacturer: assignment?.vehicle?.manufacturer,
        vehicleModel: assignment?.vehicle?.model,
        plateNumber: assignment?.vehicle?.plate_number,
        availabilityStatus: status,
        shiftStart: trip?.start_time,
        shiftEnd: trip?.end_time,
        activeTripId: trip?.id
      )
    }
  }

  private static func normalizePhone(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty
    else {
      return nil
    }

    let lower = trimmed.lowercased()
    let placeholders = ["n/a", "na", "none", "null", "not available", "unknown", "-", "—"]
    if placeholders.contains(lower) {
      return nil
    }

    return trimmed
  }
}
