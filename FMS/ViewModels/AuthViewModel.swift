//
//  AuthViewModel.swift
//  FMS
//
//  Created by Anish on 11/03/26.
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
    
    public init(selectedRole: Role? = nil, isAuthenticated: Bool = false) {
        self.selectedRole = selectedRole
        self.isAuthenticated = isAuthenticated
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
            
            struct UserRoleQuery: Decodable {
                let role: String
            }
            
            let query: [UserRoleQuery] = try await SupabaseService.shared.client
                .from("users")
                .select("role")
                .eq("email", value: email)
                .execute()
                .value
            
            if let userRecord = query.first {
                switch userRecord.role {
                case "manager":
                    self.selectedRole = .fleetManager
                case "driver":
                    self.selectedRole = .driver
                case "maintenance":
                    self.selectedRole = .maintenance
                default:
                    print("Unknown role: \(userRecord.role)")
                    return
                }
                self.isAuthenticated = true
            } else {
                bannerManager.show(type: .error, message: "Account not configured. Please contact admin.")
            }
        } catch {
            bannerManager.show(type: .error, message: "Invalid email or password. Please try again.")
        }
    }
    
    public func logout() {
        selectedRole = nil
        isAuthenticated = false
    }
}
