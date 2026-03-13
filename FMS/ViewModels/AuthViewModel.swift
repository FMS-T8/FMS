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
    public var currentUser: User?
    
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
            
            let response = try await SupabaseService.shared.client
                .from("users")
                .select()
                .eq("email", value: email)
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
    
    public func logout() async {
        try? await SupabaseService.shared.client.auth.signOut()
        selectedRole = nil
        isAuthenticated = false
        currentUser = nil
    }
}
