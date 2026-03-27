//
//  LoginView.swift
//  FMS
//

import SwiftUI

public struct LoginView: View {
    
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(BannerManager.self) private var bannerManager
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var showForgotPassword: Bool = false
    @State private var isPasswordVisible: Bool = false
    
    // ✅ Check if form is valid
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty
    }
    
    private let labelColor = Color(
        red: 130/255,
        green: 130/255,
        blue: 140/255
    )
    
    public init() {}
    
    public var body: some View {
        
        ZStack {
            FMSTheme.backgroundPrimary.ignoresSafeArea()
            
            if authViewModel.isMFARequired {
                MFAVerificationView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                VStack(spacing: 0) {
                    
                    Spacer()
                    
                    // Logo
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(FMSTheme.amber)
                            .frame(width: 80, height: 80)
                            .shadow(
                                color: FMSTheme.amber.opacity(0.3),
                                radius: 15,
                                x: 0,
                                y: 5
                            )
                        
                        Image(systemName: "box.truck")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 24)
                    
                    
                    // Title
                    Text("FleetPro")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(FMSTheme.textPrimary)
                        .padding(.bottom, 8)
                    
                    
                    // Subtitle
                    Text("Fleet Management System")
                        .font(.system(size: 16))
                        .foregroundColor(labelColor)
                        .padding(.bottom, 48)
                    
                    
                    VStack(spacing: 18) {
                        
                        // Email
                        
                        TextField("Email", text: $email)
                            .foregroundColor(FMSTheme.textPrimary)
                            .padding(.horizontal, 16)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(FMSTheme.pillBackground)
                            )
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                        
                        
                        // Password
                        
                        HStack {
                            if isPasswordVisible {
                                TextField("Password", text: $password)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            } else {
                                SecureField("Password", text: $password)
                                    .textInputAutocapitalization(.never)
                            }
                            
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isPasswordVisible.toggle()
                                }
                            }) {
                                Image(systemName: isPasswordVisible ? "eye" : "eye.slash")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(isPasswordVisible ? FMSTheme.amber : FMSTheme.textSecondary)
                                    .frame(width: 32, height: 32)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
                        }
                        .foregroundColor(FMSTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(FMSTheme.pillBackground)
                        )             
                        
                        // Login Button
                        
                        Button {
                            performLogin()
                        } label: {
                            
                            ZStack {
                                
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(FMSTheme.amber)
                                
                                if isLoading {
                                    
                                    ProgressView()
                                        .tint(.black)
                                    
                                } else {
                                    
                                    Text("Login")
                                        .fontWeight(.bold)
                                        .foregroundColor(.black)
                                }
                            }
                            .frame(height: 52)
                            .shadow(
                                color: FMSTheme.shadowMedium,
                                radius: 8,
                                y: 4
                            )
                        }
                        .opacity(isFormValid ? 1.0 : 0.6)
                        .disabled(!isFormValid || isLoading)
                        
                        
                        // Forgot password
                        
                        Button("Forgot Password?") {
                            showForgotPassword = true
                        }
                        .font(.footnote)
                        .foregroundColor(FMSTheme.textSecondary)
                        .sheet(isPresented: $showForgotPassword) {
                            ForgotPasswordView()
                                .environment(authViewModel)
                                .environment(bannerManager)
                        }
                        
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(FMSTheme.cardBackground)
                            .shadow(
                                color: FMSTheme.shadowSmall,
                                radius: 10,
                                y: 6
                            )
                    )
                    .padding(.horizontal, 24)
                    
                    
                    Spacer()
                    
                    
                    // Footer
                    
                    Text("© 2026 FLEETPRO SYSTEMS")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(FMSTheme.textTertiary)
                        .tracking(1)
                }
            }
        }
    }
    
    private func performLogin() {
        isLoading = true
        
        Task {
            await authViewModel.login(
                email: email,
                password: password,
                bannerManager: bannerManager
            )
            
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
