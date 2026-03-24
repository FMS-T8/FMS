//
//  AuthViewModel.swift
//  FMS
//
//  Created by Devanshi on 20/03/26.
//

import SwiftUI
import Observation
import Supabase

public enum Role: String, CaseIterable, Codable {
    case fleetManager = "Fleet Manager"
    case driver = "Driver"
    case maintenance = "Maintenance"
}

@MainActor
@Observable
public class AuthViewModel {
    public var selectedRole: Role?
    public var isAuthenticated: Bool = false
    public var currentUser: User?
    public var isMFARequired: Bool = false
    public var mfaFactorId: String?
    public var mfaEmail: String? = nil
    private var bannerManager: BannerManager?
    
    public init(selectedRole: Role? = nil, isAuthenticated: Bool = false, currentUser: User? = nil) {
        self.selectedRole = selectedRole
        self.isAuthenticated = isAuthenticated
        self.currentUser = currentUser
    }
    
    public func login(email: String, password: String, bannerManager: BannerManager) async {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            bannerManager.show(type: .error, message: "Please enter your email address.")
            return
        }
        
        guard email.contains("@") && email.contains(".") else {
            bannerManager.show(type: .error, message: "Please enter a valid email address.")
            return
        }
        
        guard !password.isEmpty else {
            bannerManager.show(type: .error, message: "Please enter your password.")
            return
        }
        
        do {
            try await SupabaseService.shared.client.auth.signIn(
                email: email,
                password: password
            )
        } catch {
            bannerManager.show(type: .error, message: "Invalid email or password. Please try again.")
            return
        }
        
        self.bannerManager = bannerManager
        self.mfaEmail = email
        
        do {
            // Check for MFA requirement
            let mfaStatus = try await SupabaseService.shared.client.auth.mfa.getAuthenticatorAssuranceLevel()
            if mfaStatus.nextLevel == "aal2" {
                // MFA is required. Switch to MFA state.
                let factors = try await SupabaseService.shared.client.auth.mfa.listFactors()
                let verifiedTotp = factors.totp
                    .filter { $0.status == .verified }
                    .sorted { $0.updatedAt > $1.updatedAt }
                if let firstFactor = verifiedTotp.first {
                    self.mfaFactorId = firstFactor.id
                    self.isMFARequired = true
                    // Do not set isAuthenticated yet
                    return
                } else {
                    self.isMFARequired = true
                    self.mfaFactorId = nil
                    bannerManager.show(
                        type: .error,
                        message: "MFA required but no verified TOTP factors available. Please contact admin."
                    )
                    return
                }
            }
            
            // If no MFA required, proceed to load user record
            let loginSucceeded = try await completeLogin(bannerManager: bannerManager)
            if !loginSucceeded {
                return
            }
        } catch {
            await logout()
            bannerManager.show(
                type: .error,
                message: "An error occurred during post-authentication. Please try again."
            )
        }
    }
    
    private func completeLogin(bannerManager: BannerManager, shouldSetAuthenticated: Bool = true) async throws -> Bool {
        do {
            let session = try await SupabaseService.shared.client.auth.session
            let userId = session.user.id.uuidString
            let response = try await SupabaseService.shared.client
                .from("users")
                .select()
                .eq("id", value: userId)
                .limit(1)
                .execute()
                
            let decoder = JSONDecoder()
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateStr = try container.decode(String.self)
                
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                if let date = dateFormatter.date(from: dateStr) { return date }
                
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                if let date = dateFormatter.date(from: dateStr) { return date }
                
                dateFormatter.dateFormat = "yyyy-MM-dd"
                if let date = dateFormatter.date(from: dateStr) { return date }
                
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(dateStr)")
            }
                
            let query = try decoder.decode([User].self, from: response.data)
            
            if let userRecord = query.first {
                self.currentUser = userRecord
                switch userRecord.role {
                case "manager":
                    self.selectedRole = .fleetManager
                case "driver":
                    self.selectedRole = .driver
                case "maintenance":
                    self.selectedRole = .maintenance
                default:
                    bannerManager.show(type: .error, message: "Unknown role: \(userRecord.role). Please contact admin.")
                    await logout()
                    return false
                }
                if shouldSetAuthenticated {
                    self.isAuthenticated = true
                }
                self.isMFARequired = false
                return true
            } else {
                bannerManager.show(type: .error, message: "Account not configured. Please contact admin.")
                await logout()
                return false
            }
        } catch {
            await logout()
            throw error
        }
    }

    public func verifyMFA(code: String) async {
        guard let factorId = mfaFactorId, let bannerManager = bannerManager else { return }
        
        do {
            try await SupabaseService.shared.client.auth.mfa.challengeAndVerify(
                params: MFAChallengeAndVerifyParams(factorId: factorId, code: code)
            )
        } catch {
            bannerManager.show(type: .error, message: "Invalid 2FA code. Please try again.")
            return
        }
        
        do {
            let loginSucceeded = try await completeLogin(bannerManager: bannerManager)
            if !loginSucceeded {
                await logout()
                bannerManager.show(type: .error, message: "Post-authentication failed. Please log in again.")
            }
        } catch {
            await logout()
            bannerManager.show(type: .error, message: "Post-authentication failed. Please log in again.")
        }
    }
    
    public func initiateEmailRecovery() async {
        guard let bannerManager = bannerManager else { return }
        guard let email = mfaEmail, !email.isEmpty else {
            bannerManager.show(type: .error, message: "Missing MFA email context. Please log in again.")
            return
        }
        do {
            try await MFARecoveryService.shared.sendRecoveryOTP(to: email)
            bannerManager.show(type: .success, message: "Recovery code sent to your email.")
        } catch {
            bannerManager.show(type: .error, message: "Failed to send recovery email: \(error.localizedDescription)")
        }
    }
    
    public func verifyEmailRecovery(code: String) async {
        guard let bannerManager = bannerManager else { return }
        guard let email = mfaEmail, !email.isEmpty else {
            bannerManager.show(type: .error, message: "Missing MFA email context. Please log in again.")
            return
        }
        do {
            let success = try await MFARecoveryService.shared.verifyEmailRecoveryAndResetMFA(email: email, code: code)
            if success {
                bannerManager.show(type: .success, message: "MFA has been reset. Please log in again.")
                await logout() // Return to login screen
            } else {
                bannerManager.show(type: .error, message: "Invalid recovery code.")
            }
        } catch {
            bannerManager.show(type: .error, message: "Recovery failed: \(error.localizedDescription)")
        }
    }
    
    public func verifyBackupCode(code: String) async {
        guard let bannerManager = bannerManager else { return }
        do {
            // We need the user ID for backup code verification. 
            // Since we're partially logged in, we can get it from the session.
            let session = try await SupabaseService.shared.client.auth.session
            let userId = session.user.id.uuidString
            let valid = try await MFARecoveryService.shared.validateBackupCode(userId: userId, code: code)
            
            if valid {
                let loginSucceeded = try await completeLogin(bannerManager: bannerManager, shouldSetAuthenticated: false)
                if !loginSucceeded {
                    return
                }
                let consumed = try await MFARecoveryService.shared.consumeBackupCode(userId: userId, code: code)
                if consumed {
                    self.isAuthenticated = true
                    bannerManager.show(type: .success, message: "Backup code verified successfully. Logging you in.")
                } else {
                    await logout()
                    bannerManager.show(type: .error, message: "Failed to consume backup code. Please log in again.")
                }
            } else {
                bannerManager.show(type: .error, message: "Invalid or already used backup code.")
            }
        } catch {
            await logout()
            bannerManager.show(type: .error, message: "Verification failed: \(error.localizedDescription)")
        }
    }
  
    
    public func sendPasswordReset(email: String, bannerManager: BannerManager) async -> Bool { // ✅ return Bool
        
        // Add email validation (mirrors login)
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            bannerManager.show(type: .error, message: "Please enter your email address.")
            return false
        }
        
        guard email.contains("@") && email.contains(".") else {
            bannerManager.show(type: .error, message: "Please enter a valid email address.")
            return false
        }
        
        // Safe URL unwrap instead of force unwrap
        guard let redirectURL = URL(string: "com.nirvaan.fms://reset-password") else {
            bannerManager.show(type: .error, message: "Invalid configuration. Please contact support.")
            return false
        }
        
        do {
            try await SupabaseService.shared.client.auth.resetPasswordForEmail(
                email,
                redirectTo: redirectURL
            )
            bannerManager.show(type: .success, message: "Reset link sent to \(email)")
            return true  
        } catch {
            bannerManager.show(type: .error, message: error.localizedDescription)
            return false  
        }
    }
    
    public func logout() async {
        do {
            try await SupabaseService.shared.client.auth.signOut()
        } catch {
            print("Auth signOut failed: \(error)")
        }
        selectedRole = nil
        isAuthenticated = false
        currentUser = nil
        isMFARequired = false
        mfaFactorId = nil
        mfaEmail = nil
        bannerManager = nil
    }
}
