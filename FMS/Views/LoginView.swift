import SwiftUI

public struct LoginView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(BannerManager.self) private var bannerManager
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    
    // Adaptive colors
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 18/255, green: 18/255, blue: 20/255) : Color(red: 247/255, green: 247/255, blue: 249/255)
    }
    
    private var textColor: Color {
        colorScheme == .dark ? .white : Color(red: 30/255, green: 30/255, blue: 40/255)
    }
    
    private let labelColor = Color(red: 130/255, green: 130/255, blue: 140/255)
    
    public init() {}
    
    public var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(FMSTheme.amber)
                        .frame(width: 80, height: 80)
                        .shadow(color: FMSTheme.amber.opacity(0.3), radius: 15, x: 0, y: 5)
                    
                    Image(systemName: "box.truck")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 24)
                
                // App Title
                Text("FleetPro")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(textColor)
                    .padding(.bottom, 8)
                
                // Subtitle
                Text("Fleet Management System")
                    .font(.system(size: 16))
                    .foregroundColor(labelColor)
                    .padding(.bottom, 48)
                
                // Input Fields
                VStack(spacing: 20) {
                    FMSTextField(
                        label: "Email Address",
                        placeholder: "name@fleetpro.com",
                        icon: "at",
                        text: $email
                    )
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    
                    FMSTextField(
                        label: "Password",
                        placeholder: "••••••••",
                        icon: "lock",
                        text: $password,
                        isSecure: true,
                        trailingAction: {
                            // Forgot password action
                        },
                        trailingLabel: "Forgot Password?"
                    )
                    .textContentType(.password)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                
                // Login Button
                Button {
                    performLogin()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.9)
                        } else {
                            Text("Login")
                                .font(.system(size: 17, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(FMSTheme.amber)
                    .cornerRadius(16)
                    .shadow(color: FMSTheme.amber.opacity(0.2), radius: 10, x: 0, y: 5)
                }
                .disabled(isLoading)
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Footer
                Text("© 2026 FLEETPRO SYSTEMS")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(labelColor)
                    .tracking(1.0)
                    .padding(.bottom, 20)
            }
        }
    }
    
    private func performLogin() {
        isLoading = true
        
        Task {
            await authViewModel.login(email: email, password: password, bannerManager: bannerManager)
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

#Preview("Light Mode") {
    LoginView()
        .environment(AuthViewModel())
        .environment(BannerManager())
        .colorScheme(.light)
}

#Preview("Dark Mode") {
    LoginView()
        .environment(AuthViewModel())
        .environment(BannerManager())
        .colorScheme(.dark)
}
