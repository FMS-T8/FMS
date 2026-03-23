//
//  ForgotPasswordView.swift
//  FMS
//
//  Created by user@50 on 20/03/26.
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(BannerManager.self) private var bannerManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var email: String = ""
    @State private var isLoading: Bool = false
    @State private var isEmailSent: Bool = false
    
    private var isFormValid: Bool { !email.isEmpty }
    
    var body: some View {
        NavigationStack {
            ZStack {
                FMSTheme.backgroundPrimary.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(FMSTheme.amber)
                            .frame(width: 64, height: 64)
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Reset Password")
                            .font(.title2.bold())
                            .foregroundColor(FMSTheme.textPrimary)
                        
                        Text("Enter your email and we'll send you a reset link.")
                            .font(.subheadline)
                            .foregroundColor(FMSTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    if isEmailSent {
                        
                        
                        Label("Reset link sent! Check your inbox.", systemImage: "checkmark.circle.fill")
                            .foregroundColor(FMSTheme.amber)  // ✅ instead of .green
                            .font(.subheadline)
                    } else {
                        VStack(spacing: 16) {
                            TextField("Email", text: $email)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(FMSTheme.pillBackground)
                                )
                                .foregroundColor(FMSTheme.textPrimary)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                            
                            Button {
                                sendResetEmail()
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(FMSTheme.amber)
                                    if isLoading {
                                        ProgressView().tint(.black)
                                    } else {
                                        Text("Send Reset Link")
                                            .fontWeight(.bold)
                                            .foregroundColor(.black)
                                    }
                                }
                                .frame(height: 52)
                            }
                            .opacity(isFormValid ? 1.0 : 0.6)
                            .disabled(!isFormValid || isLoading)
                        }
                    }
                    
                    Spacer()
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(FMSTheme.amber)
                    
                }
            }
        }
    }
    
    // ✅ Use return value to conditionally set isEmailSent
    private func sendResetEmail() {
        isLoading = true
        Task {
            let success = await authViewModel.sendPasswordReset(
                email: email,
                bannerManager: bannerManager
            )
            await MainActor.run {
                isLoading = false
                if success {          // ✅ only show success UI if it actually succeeded
                    isEmailSent = true
                }
            }
        }
        
    }
}
