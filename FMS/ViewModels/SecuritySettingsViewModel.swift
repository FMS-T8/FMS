//
//  SecuritySettingsViewModel.swift
//  FMS
//

import Foundation
import Observation
import Supabase

@MainActor
@Observable
public final class SecuritySettingsViewModel {
    
    public var isTwoFactorEnabled: Bool = false
    public var isEnrollingMFA: Bool = false
    public var mfaEnrollmentResponse: AuthMFAEnrollResponse?
    public var recoveryCodes: [String] = []
    public var errorMessage: String? = nil
    
    private var email: String = ""
    private var userId: String = ""
    
    public init() {}
    
    public func loadSecurityState() async {
        do {
            let session = try await SupabaseService.shared.client.auth.session
            self.email = session.user.email ?? ""
            self.userId = session.user.id.uuidString
            
            struct UserProfile: Decodable {
                let two_factor_enabled: Bool?
            }
            let profiles: [UserProfile] = try await SupabaseService.shared.client
                .from("users")
                .select("two_factor_enabled")
                .eq("id", value: self.userId)
                .limit(1)
                .execute()
                .value
            
            if let row = profiles.first {
                self.isTwoFactorEnabled = row.two_factor_enabled ?? false
            }
        } catch {
            if String(describing: error).contains("sessionMissing") {
                return
            }
            print("Failed to load security state: \(error)")
        }
    }
    
    public func initiateMFAEnrollment() async {
        isEnrollingMFA = true
        errorMessage = nil
        mfaEnrollmentResponse = nil
        recoveryCodes = []
        defer { isEnrollingMFA = false }
        
        do {
            if self.email.isEmpty {
                await loadSecurityState()
            }
            
            // Clean up any unverified factors that might be lingering from a failed setup
            if let factors = try? await SupabaseService.shared.client.auth.mfa.listFactors() {
                for factor in factors.all where factor.factorType == "totp" && factor.status == .unverified {
                    _ = try? await SupabaseService.shared.client.auth.mfa.unenroll(params: MFAUnenrollParams(factorId: factor.id))
                }
            }

            let response = try await SupabaseService.shared.client.auth.mfa.enroll(
                params: .totp(issuer: "FleetPro", friendlyName: self.email)
            )
            self.mfaEnrollmentResponse = response
        } catch {
            errorMessage = "Failed to initiate MFA enrollment: \(error.localizedDescription)"
            mfaEnrollmentResponse = nil
        }
    }
    
    public func verifyMFAEnrollment(code: String, bannerManager: BannerManager) async -> Bool {
        guard let factorId = mfaEnrollmentResponse?.id else { return false }
        
        do {
            try await SupabaseService.shared.client.auth.mfa.challengeAndVerify(
                params: MFAChallengeAndVerifyParams(factorId: factorId, code: code)
            )
        } catch {
            bannerManager.show(type: .error, message: "Invalid verification code. Please try again.")
            return false
        }
            
        do {
            self.recoveryCodes = try await MFARecoveryService.shared.generateAndStoreBackupCodes(userId: self.userId)
            try await setTwoFactorEnabled(true)
            bannerManager.show(type: .success, message: "Two-factor authentication enabled.")
            return true
        } catch {
            bannerManager.show(type: .warning, message: "MFA Activated, but failed to save backup codes. \(error.localizedDescription)")
            var unenrollSucceeded = false
            do {
                try await SupabaseService.shared.client.auth.mfa.unenroll(
                    params: MFAUnenrollParams(factorId: factorId)
                )
                unenrollSucceeded = true
            } catch {
                print("Failed to rollback MFA factor: \(error)")
            }
            if unenrollSucceeded {
                try? await setTwoFactorEnabled(false)
            }
            recoveryCodes = []
            return false
        }
    }
    
    public func unenrollAllMFAFactors(bannerManager: BannerManager) async {
        do {
            let factorsResponse = try await SupabaseService.shared.client.auth.mfa.listFactors()
            var didUnenroll = false
            for factor in factorsResponse.all where factor.factorType == "totp" {
                try await SupabaseService.shared.client.auth.mfa.unenroll(params: MFAUnenrollParams(factorId: factor.id))
                didUnenroll = true
            }
            
            if didUnenroll {
                try await setTwoFactorEnabled(false)
            }
            bannerManager.show(type: .success, message: "Two-factor authentication disabled limitlessly.")
        } catch {
            bannerManager.show(type: .error, message: "Failed to disable MFA: \(error.localizedDescription)")
        }
    }
    
    private func setTwoFactorEnabled(_ enabled: Bool) async throws {
        struct Updates: Encodable { let two_factor_enabled: Bool }
        try await SupabaseService.shared.client
            .from("users")
            .update(Updates(two_factor_enabled: enabled))
            .eq("id", value: self.userId)
            .execute()
        self.isTwoFactorEnabled = enabled
    }
}
