import SwiftUI

public struct RoleSelectionView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    
    // Internal selection state for the UI before confirming
    @State private var pendingSelection: Role? = nil
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                FMSTheme.obsidian.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    VStack(spacing: 8) {
                        Image(systemName: "box.truck.badge.clock.fill")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(FMSTheme.amber)
                        
                        Text("FMS Gateway")
                            .font(.largeTitle.weight(.heavy))
                            .foregroundColor(.white)
                        
                        Text("Select your operating role")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 20)
                    
                    VStack(spacing: 16) {
                        FMSRoleCard(
                            title: "Fleet Manager",
                            systemImage: "briefcase.fill",
                            description: "Manage assets, track vehicles, and review analytics.",
                            isSelected: pendingSelection == .fleetManager,
                            action: { pendingSelection = .fleetManager }
                        )
                        
                        FMSRoleCard(
                            title: "Driver",
                            systemImage: "steeringwheel",
                            description: "Log trips, fuel, and inspect vehicles.",
                            isSelected: pendingSelection == .driver,
                            action: { pendingSelection = .driver }
                        )
                        
                        FMSRoleCard(
                            title: "Maintenance",
                            systemImage: "wrench.and.screwdriver.fill",
                            description: "Process service requests and update inventory.",
                            isSelected: pendingSelection == .maintenance,
                            action: { pendingSelection = .maintenance }
                        )
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    Button("Enter System") {
                        if let selection = pendingSelection {
                            withAnimation {
                                authViewModel.selectRole(selection)
                            }
                        }
                    }
                    .buttonStyle(.fmsPrimary)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .disabled(pendingSelection == nil)
                    .opacity(pendingSelection == nil ? 0.5 : 1.0)
                }
            }
        }
    }
}
