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
    
    public func login(email: String, password: String) async {
        do {
            // Note for testing: Since dummy emails were used without confirmation, 
            // auth.signIn() will fail with "Email not confirmed". We bypass Supabase Auth 
            // for now and directly query the role from `public.users` matching the email.
            
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
                print("No user found with email \(email)")
            }
        } catch {
            print("Login failed: \(error)")
        }
    }
    
    public func logout() {
        selectedRole = nil
        isAuthenticated = false
    }
}
