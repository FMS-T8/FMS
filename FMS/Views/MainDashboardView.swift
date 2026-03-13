import SwiftUI

public struct MainDashboardView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    
    public init() {}
    
    public var body: some View {
        Group {
            switch authViewModel.selectedRole {
            case .fleetManager:
                FleetManagerDashboardView()
            case .driver:
                DriverDashboardView()
            case .maintenance:
                MaintenanceTabView()
            case .none:
                placeholderView(role: "Unknown")
            }
        }
    }
    
    @ViewBuilder
    private func placeholderView(role: String) -> some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 80))
                        .foregroundColor(FMSTheme.amber)
                    
                    Text("Welcome to Dashboard")
                        .font(.title.weight(.bold))
                    
                    Text("Logged in as **\(role)**")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Spacer().frame(height: 40)
                    
                    Button("Logout") {
                        Task {
                            await authViewModel.logout()
                        }
                    }
                    .buttonStyle(.fmsPrimary)
                    .padding(.horizontal, 40)
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
