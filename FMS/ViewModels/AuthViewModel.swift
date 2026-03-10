import SwiftUI
import Observation

public enum Role: String, CaseIterable, Codable {
    case fleetManager = "Fleet Manager"
    case driver = "Driver"
    case maintenance = "Maintenance"
}

@Observable
public class AuthViewModel {
    public var selectedRole: Role?
    
    public init(selectedRole: Role? = nil) {
        self.selectedRole = selectedRole
    }
    
    public func selectRole(_ role: Role) {
        selectedRole = role
    }
    
    public func logout() {
        selectedRole = nil
    }
}
