import SwiftUI

public struct MainDashboardView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 80))
                        .foregroundColor(FMSTheme.amber)
                    
                    Text("Welcome to Dashboard")
                        .font(.title.weight(.bold))
                    
                    if let role = authViewModel.selectedRole {
                        Text("Logged in as **\(role.rawValue)**")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer().frame(height: 40)
                    
                    Button("Logout") {
                        withAnimation {
                            authViewModel.logout()
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
