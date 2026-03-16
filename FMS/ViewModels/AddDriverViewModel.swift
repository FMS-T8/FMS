//
//  AddDriverViewModel.swift
//  FMS
//
//  Created by devanshi on 12/03/26.
//

import Foundation
import Supabase
import Combine

@MainActor
class AddDriverViewModel: ObservableObject {
    @Published var name = ""
    @Published var email = ""
    @Published var phone = ""
    @Published var licenseNumber = ""
    @Published var dateOfBirth: Date?
    // Default to tomorrow so the field is valid out-of-the-box and the
    // DatePicker's in: Date()... range is immediately satisfied.
    @Published var licenseExpiry = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""

    // Role passed in from the tab — not user-selectable
    var role: String

    init(role: String = "driver") {
        self.role = role
    }

    var isValid: Bool {
        let isNameValid = !name.trimmingCharacters(in: .whitespaces).isEmpty

        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        let isEmailValid = emailPredicate.evaluate(with: email)

        let isLicenseValid = !licenseNumber.trimmingCharacters(in: .whitespaces).isEmpty

        // Expiry must be today or in the future (compare date components only,
        // ignoring time, so "today" itself counts as valid).
        let today = Calendar.current.startOfDay(for: Date())
        let expiryDay = Calendar.current.startOfDay(for: licenseExpiry)
        let isExpiryValid = expiryDay >= today

        return isNameValid && isEmailValid && isLicenseValid && isExpiryValid
    }

    func applyScannedLicense(_ result: DriverLicenseReviewData) {
        name = result.fullName
        licenseNumber = result.licenseNumber
        if let expiry = result.expiryDate {
            licenseExpiry = expiry
        }
        dateOfBirth = result.dateOfBirth
    }

    func createDriver(onSuccess: @escaping () -> Void) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await SupabaseService.shared.client.auth.session
            let currentUserId = session.user.id.uuidString

            struct NewUserPayload: Encodable {
                let name: String
                let email: String
                let phone: String
                let role: String
                let license_number: String
                let license_expiry: String
                let created_by: String
            }

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]

            let payload = NewUserPayload(
                name: name,
                email: email,
                phone: phone,
                role: role,
                license_number: licenseNumber,
                license_expiry: formatter.string(from: licenseExpiry),
                created_by: currentUserId
            )

            // Calls Edge Function — NOT direct DB insert
            try await SupabaseService.shared.client.functions
                .invoke(
                    "create-user",
                    options: FunctionInvokeOptions(body: payload)
                )

            onSuccess()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
