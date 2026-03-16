//
//  ManagerProfileViewModel.swift
//  FMS
//
//  Created by Nikunj Mathur on 13/03/26.
//

import SwiftUI
import Observation
import Supabase

// MARK: - Manager Profile Data

/// Row returned from the `users` table for the logged-in manager.
struct ManagerProfileRow: Decodable {
    let id: String
    let name: String
    let email: String
    let phone: String
    let role: String
    let employeeId: String?
    let mapPreference: String?
    let units: String?
    let twoFactorEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case phone
        case role
        case employeeId       = "employee_id"
        case mapPreference    = "map_preference"
        case units
        case twoFactorEnabled = "two_factor_enabled"
    }
}

/// Row returned when counting the fleet size.
private struct VehicleCountRow: Decodable {
    let count: Int?
}

// MARK: - Map Preference / Units

enum MapPreference: String, CaseIterable, Identifiable {
    case standard  = "standard"
    case satellite = "satellite"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .standard:  return "Standard"
        case .satellite: return "Satellite"
        }
    }
}

enum DistanceUnit: String, CaseIterable, Identifiable {
    case km    = "km"
    case miles = "miles"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .km:    return "Kilometers"
        case .miles: return "Miles"
        }
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class ManagerProfileViewModel {

    // -- Profile
    var name: String        = ""
    var email: String       = ""
    var phone: String       = ""
    var role: String        = ""
    var employeeId: String  = "—"

    // -- Security
    var isTwoFactorEnabled: Bool = false

    // -- Preferences
    var mapPreference: MapPreference = .standard
    var distanceUnit: DistanceUnit   = .km

    // -- Fleet
    var fleetSize: Int = 0
    var driverCount: Int = 0
    var maintenanceCount: Int = 0

    // -- State
    var isLoading: Bool      = false
    var errorMessage: String? = nil

    // -- Change Password
    var currentPassword: String  = ""
    var newPassword: String      = ""
    var confirmPassword: String  = ""
    var isChangingPassword: Bool = false
    var passwordError: String?   = nil
    var passwordSuccess: Bool    = false

    // MARK: - Load

    func loadAll() async {
        isLoading = true
        errorMessage = nil

        async let profileTask: () = loadProfile()
        async let fleetTask: ()   = loadFleetSize()

        _ = await (profileTask, fleetTask)
        isLoading = false
    }

    private func loadProfile() async {
        do {
            // Get the currently signed-in user's email from the Supabase session
            let session = try await SupabaseService.shared.client.auth.session
            let userEmail = session.user.email ?? ""

            let rows: [ManagerProfileRow] = try await SupabaseService.shared.client
                .from("users")
                .select("id, name, email, phone, role, employee_id, map_preference, units, two_factor_enabled")
                .eq("email", value: userEmail)
                .limit(1)
                .execute()
                .value

            if let row = rows.first {
                name       = row.name
                email      = row.email
                phone      = row.phone
                role       = row.role.capitalized
                employeeId = row.employeeId ?? "—"
                isTwoFactorEnabled = row.twoFactorEnabled ?? false
                mapPreference = MapPreference(rawValue: row.mapPreference ?? "standard") ?? .standard
                distanceUnit  = DistanceUnit(rawValue: row.units ?? "km") ?? .km
            }
        } catch {
            errorMessage = "Failed to load profile: \(error.localizedDescription)"
        }
    }

    private func loadFleetSize() async {
        do {
            // Vehicle count
            struct IDOnly: Decodable { let id: String }

            async let vehiclesTask: [IDOnly] = SupabaseService.shared.client
                .from("vehicles")
                .select("id")
                .execute()
                .value

            async let driversTask: [IDOnly] = SupabaseService.shared.client
                .from("users")
                .select("id")
                .eq("role", value: "driver")
                .execute()
                .value

            async let maintenanceTask: [IDOnly] = SupabaseService.shared.client
                .from("users")
                .select("id")
                .eq("role", value: "maintenance")
                .execute()
                .value

            let (vehicles, drivers, maintenance) = try await (vehiclesTask, driversTask, maintenanceTask)
            fleetSize        = vehicles.count
            driverCount      = drivers.count
            maintenanceCount = maintenance.count
        } catch {
            // Non-critical; leave counts at 0
        }
    }

    // MARK: - Save Preferences

    func savePreferences() async {
        do {
            let session = try await SupabaseService.shared.client.auth.session
            let userEmail = session.user.email ?? ""

            try await SupabaseService.shared.client
                .from("users")
                .update([
                    "map_preference"     : mapPreference.rawValue,
                    "units"              : distanceUnit.rawValue,
                    "two_factor_enabled" : isTwoFactorEnabled ? "true" : "false"
                ])
                .eq("email", value: userEmail)
                .execute()
        } catch {
            errorMessage = "Failed to save preferences: \(error.localizedDescription)"
        }
    }

    // MARK: - Change Password

    func changePassword(bannerManager: BannerManager) async {
        passwordError   = nil
        passwordSuccess = false

        guard !currentPassword.isEmpty else {
            passwordError = "Enter your current password."
            return
        }
        guard newPassword.count >= 8 else {
            passwordError = "New password must be at least 8 characters."
            return
        }
        guard newPassword == confirmPassword else {
            passwordError = "Passwords do not match."
            return
        }

        isChangingPassword = true
        defer { isChangingPassword = false }

        do {
            // Re-authenticate with the current password first
            let session = try await SupabaseService.shared.client.auth.session
            let userEmail = session.user.email ?? ""
            try await SupabaseService.shared.client.auth.signIn(
                email: userEmail,
                password: currentPassword
            )
            // Now update the password
            try await SupabaseService.shared.client.auth.update(
                user: UserAttributes(password: newPassword)
            )
            currentPassword  = ""
            newPassword      = ""
            confirmPassword  = ""
            passwordSuccess  = true
            bannerManager.show(type: .success, message: "Password changed successfully.")
        } catch {
            passwordError = "Incorrect current password or server error."
        }
    }
}
