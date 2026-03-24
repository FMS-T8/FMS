//
//  MFARecoveryService.swift
//  FMS
//

import Foundation
import Supabase

/// A service to handle MFA recovery flows, including Email OTP and backup codes.
public final class MFARecoveryService {
    public static let shared = MFARecoveryService()
    
    private let client = SupabaseService.shared.client
    
    private init() {}
    
    /// Initiates the email recovery flow by sending an OTP to the user's email.
    /// - Parameter email: The user's email address.
    public func sendRecoveryOTP(to email: String) async throws {
        // We use the standard signInWithOTP flow, but the app will handle it as a recovery step.
        // If MFA is required for this user, this OTP won't log them in fully, but we verify it via an Edge Function.
        try await client.auth.signInWithOTP(email: email)
    }
    
    /// Verifies the recovery OTP and resets the MFA factor if successful.
    /// - Parameters:
    ///   - email: The user's email address.
    ///   - code: The 6-digit OTP received via email.
    /// - Returns: True if MFA was successfully reset.
    public func verifyEmailRecoveryAndResetMFA(email: String, code: String) async throws -> Bool {
        // We call a Supabase Edge Function that verifies the OTP and then uses service_role to unenroll the MFA factor.
        try await client.functions.invoke(
            "verify-recovery-otp",
            options: FunctionInvokeOptions(
                body: ["email": email, "token": code]
            )
        )
        return true
    }
    
    /// Verifies a backup recovery code.
    /// - Parameters:
    ///   - userId: The ID of the user.
    ///   - code: The 10-character recovery code.
    /// - Returns: True if the code is valid and unused.
    public func verifyBackupCode(userId: String, code: String) async throws -> Bool {
        struct RecoveryCode: Decodable {
            let id: UUID
        }
        
        // Query the custom `mfa_recovery_codes` table.
        let codes: [RecoveryCode] = try await client
            .from("mfa_recovery_codes")
            .select("id")
            .eq("user_id", value: userId)
            .eq("code", value: code)
            .filter("used_at", operator: "is", value: "null")
            .execute()
            .value
        
        if !codes.isEmpty {
            // Mark the code as used
            struct Updates: Encodable { let used_at: Date }
            try await client
                .from("mfa_recovery_codes")
                .update(Updates(used_at: Date()))
                .eq("user_id", value: userId)
                .eq("code", value: code)
                .execute()
            
            return true
        }
        return false
    }
    
    /// Generates a set of 8 random backup codes for a user.
    /// - Parameter userId: The ID of the user.
    /// - Returns: An array of 10-character alphanumeric codes.
    public func generateAndStoreBackupCodes(userId: String) async throws -> [String] {
        var codes: [String] = []
        for _ in 0..<8 {
            codes.append(UUID().uuidString.prefix(10).lowercased())
        }
        
        // Store them in the custom table (assuming it exists or will be created)
        let entries = codes.map { ["user_id": userId, "code": $0] }
        try await client
            .from("mfa_recovery_codes")
            .insert(entries)
            .execute()
            
        return codes
    }
}
