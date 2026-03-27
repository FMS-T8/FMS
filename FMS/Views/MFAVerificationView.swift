//
//  MFAVerificationView.swift
//  FMS
//

import SwiftUI

struct MFAVerificationView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(BannerManager.self) private var bannerManager
    
    @State private var code: String = ""
    @State private var isVerifying: Bool = false
    @State private var recoveryMode: RecoveryMode = .none
    
    enum RecoveryMode {
        case none
        case email
        case backupCode
    }
    
    var body: some View {
        VStack(spacing: 32) {
            headerSection
            
            VStack(spacing: 24) {
                codeInputField
                
                verifyButton
                
                recoveryOptions
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .padding(.top, 40)
        .background(FMSTheme.backgroundPrimary)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    Task { await authViewModel.logout() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back to Login")
                    }
                    .font(.system(size: 16))
                    .foregroundStyle(FMSTheme.amber)
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: recoveryModeIcon)
                .font(.system(size: 48))
                .foregroundStyle(FMSTheme.amber)
            
            Text(recoveryModeTitle)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)
            
            Text(recoveryModeSubtitle)
                .font(.system(size: 15))
                .foregroundStyle(FMSTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Input
    
    private var codeInputField: some View {
        TextField(recoveryMode == .backupCode ? "7a1acfd1-f" : "000000", text: $code)
            .font(.system(size: 28, weight: .bold, design: .monospaced))
            .foregroundStyle(FMSTheme.textPrimary)
            .keyboardType(recoveryMode == .backupCode ? .default : .numberPad)
            .multilineTextAlignment(.center)
            .frame(height: 64)
            .background(FMSTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(FMSTheme.amber.opacity(0.3), lineWidth: 1)
            )
            .textInputAutocapitalization(recoveryMode == .backupCode ? .never : .characters)
            .autocorrectionDisabled()
            .onChange(of: code) { _, newValue in
                if recoveryMode == .backupCode {
                    let normalized = newValue
                        .lowercased()
                        .filter { $0.isLetter || $0.isNumber || $0 == "-" }
                    let limited = String(normalized.prefix(10))
                    if limited != newValue {
                        code = limited
                    }
                } else {
                    let filtered = newValue.filter { $0.isNumber }
                    let limited = String(filtered.prefix(6))
                    if limited != newValue {
                        code = limited
                    }
                }
            }
            .onChange(of: recoveryMode) { _, newValue in
                if newValue == .backupCode {
                    code = ""
                } else {
                    let filtered = code.filter { $0.isNumber }
                    code = String(filtered.prefix(6))
                }
            }
    }
    
    // MARK: - Verify Button
    
    private var verifyButton: some View {
        Button {
            Task {
                isVerifying = true
                switch recoveryMode {
                case .none:
                    await authViewModel.verifyMFA(code: code)
                case .email:
                    await authViewModel.verifyEmailRecovery(code: code)
                case .backupCode:
                    await authViewModel.verifyBackupCode(code: code.lowercased().trimmingCharacters(in: .whitespaces))
                }
                isVerifying = false
            }
        } label: {
            if isVerifying {
                ProgressView()
                    .tint(.black)
            } else {
                Text(recoveryMode == .none ? "Verify" : "Recover Account")
                    .font(.system(size: 16, weight: .bold))
            }
        }
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(FMSTheme.amber)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .disabled(
            isVerifying ||
            (recoveryMode == .backupCode ? code.count != 10 : code.count != 6)
        )
    }
    
    // MARK: - Recovery Options
    
    private var recoveryOptions: some View {
        VStack(spacing: 16) {
            if recoveryMode == .none {
                Button("Lost your device?") {
                    withAnimation {
                        recoveryMode = .email
                        code = ""
                    }
                    Task { await authViewModel.initiateEmailRecovery() }
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(FMSTheme.textTertiary)
            } else {
                HStack(spacing: 20) {
                    if recoveryMode != .email {
                        Button("Use Email") {
                            withAnimation { 
                                recoveryMode = .email
                                code = ""
                            }
                            Task { await authViewModel.initiateEmailRecovery() }
                        }
                    }
                    
                    if recoveryMode != .backupCode {
                        Button("Use Backup Code") {
                            withAnimation { 
                                recoveryMode = .backupCode
                                code = ""
                            }
                        }
                    }
                    
                    Button("Try TOTP") {
                        withAnimation { 
                            recoveryMode = .none
                            code = ""
                        }
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FMSTheme.amber)
                
                if recoveryMode == .email {
                    Button("Resend Email Code") {
                        Task { await authViewModel.initiateEmailRecovery() }
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(FMSTheme.textTertiary)
                    .padding(.top, 4)
                }
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Helpers
    
    private var recoveryModeIcon: String {
        switch recoveryMode {
        case .none: return "lock.shield.fill"
        case .email: return "envelope.badge.shield.half.filled"
        case .backupCode: return "key.fill"
        }
    }
    
    private var recoveryModeTitle: String {
        switch recoveryMode {
        case .none: return "Two-Factor Auth"
        case .email: return "Email Recovery"
        case .backupCode: return "Backup Code"
        }
    }
    
    private var recoveryModeSubtitle: String {
        switch recoveryMode {
        case .none: return "Enter the 6-digit code from your authenticator app."
        case .email: return "We've sent a 6-digit verification code to your registered email."
        case .backupCode: return "Enter one of the 10-character backup codes you saved during setup."
        }
    }
}
