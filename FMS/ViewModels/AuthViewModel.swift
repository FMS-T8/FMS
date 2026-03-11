import SwiftUI
import Observation
import Supabase

public enum Role: String, CaseIterable, Codable {
    case fleetManager = "Fleet Manager"
    case driver = "Driver"
    case maintenance = "Maintenance"
}

@Observable
public class AuthViewModel {
    public var selectedRole: Role?
    public var isAuthenticated: Bool = false
    
    public init(selectedRole: Role? = nil, isAuthenticated: Bool = false) {
        self.selectedRole = selectedRole
        self.isAuthenticated = isAuthenticated
    }
    
    public func login(email: String, password: String, bannerManager: BannerManager) async {
        // Input validation
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            await bannerManager.show(type: .error, message: "Please enter your email address.")
            return
        }
        
        guard email.contains("@") && email.contains(".") else {
            await bannerManager.show(type: .error, message: "Please enter a valid email address.")
            return
        }
        
        guard !password.isEmpty else {
            await bannerManager.show(type: .error, message: "Please enter your password.")
            return
        }
        
        do {
            // Authenticate via Supabase Auth to validate password
            try await SupabaseService.shared.client.auth.signIn(
                email: email,
                password: password
            )
            
            // Fetch role from public.users table
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
                await MainActor.run {
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
                }
            } else {
                await bannerManager.show(type: .error, message: "Account not configured. Please contact admin.")
            }
        } catch {
            await bannerManager.show(type: .error, message: "Invalid email or password. Please try again.")
        }
    }
    
    public func logout() {
        selectedRole = nil
        isAuthenticated = false
    }
}
