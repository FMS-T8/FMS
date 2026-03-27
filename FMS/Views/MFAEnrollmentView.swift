//
//  MFAEnrollmentView.swift
//  FMS
//

import SwiftUI
import Supabase

struct MFAEnrollmentView: View {
    var vm: SecuritySettingsViewModel
    var bannerManager: BannerManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var verificationCode: String = ""
    @State private var isVerifying: Bool = false
    @State private var showRecoveryCodes: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if !showRecoveryCodes {
                        setupInstructions
                        qrCodeSection
                        verificationSection
                    } else {
                        recoveryCodesSection
                    }
                }
                .padding(24)
            }
            .presentationBackground(FMSTheme.backgroundPrimary)
            .navigationTitle("2FA Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(FMSTheme.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Setup Instructions
    
    private var setupInstructions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Secure your account")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)
            
            Text("Scan the QR code below with an authenticator app (like Google Authenticator or Authy) to link your account.")
                .font(.system(size: 15))
                .foregroundStyle(FMSTheme.textSecondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - QR Code Section
    
    private var qrCodeSection: some View {
        VStack(spacing: 16) {
            if let totp = vm.mfaEnrollmentResponse?.totp,
               let qrImage = QRCodeGenerator.generate(from: totp.uri, size: CGSize(width: 200, height: 200)) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .padding(12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.1), radius: 10)
            } else {
                ProgressView()
                    .tint(FMSTheme.amber)
                    .frame(width: 200, height: 200)
            }
            
            if let totp = vm.mfaEnrollmentResponse?.totp {
                VStack(spacing: 8) {
                    Text("Manual Entry Key")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FMSTheme.textTertiary)
                        .textCase(.uppercase)
                    
                    // Secret key pill — tap to copy
                    Button {
                        UIPasteboard.general.string = totp.secret
                        bannerManager.show(type: .success, message: "Secret key copied to clipboard!")
                    } label: {
                        HStack(spacing: 6) {
                            Text(totp.secret)
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(FMSTheme.amber)
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 12))
                                .foregroundStyle(FMSTheme.amber.opacity(0.7))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(FMSTheme.amber.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(FMSTheme.amber.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    
                    // Open in authenticator app
                    Button {
                        if let url = URL(string: totp.uri) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open in Authenticator App", systemImage: "qrcode.viewfinder")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(FMSTheme.amber)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Verification Section
    
    private var verificationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enter the 6-digit code")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FMSTheme.textSecondary)
            
            TextField("000000", text: $verificationCode)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(FMSTheme.textPrimary)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(height: 60)
                .background(FMSTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(FMSTheme.amber.opacity(0.3), lineWidth: 1)
                )
                .onChange(of: verificationCode) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    let limited = String(filtered.prefix(6))
                    if limited != newValue {
                        verificationCode = limited
                    }
                }
            
            Button {
                Task {
                    isVerifying = true
                    let success = await vm.verifyMFAEnrollment(code: verificationCode, bannerManager: bannerManager)
                    isVerifying = false
                    if success {
                        withAnimation { showRecoveryCodes = true }
                    }
                }
            } label: {
                if isVerifying {
                    ProgressView()
                        .tint(.black)
                } else {
                    Text("Verify & Activate")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(FMSTheme.amber)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .disabled(verificationCode.count != 6 || isVerifying)
        }
    }
    
    // MARK: - Recovery Codes Section
    
    private var recoveryCodesSection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(FMSTheme.amber)
                
                Text("2FA is now active!")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(FMSTheme.textPrimary)
                
                Text("Save these backup codes in a safe place. You can use them to log in if you lose access to your authenticator device.")
                    .font(.system(size: 15))
                    .foregroundStyle(FMSTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                ForEach(vm.recoveryCodes, id: \.self) { code in
                    HStack {
                        Text(code)
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundStyle(FMSTheme.textPrimary)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    
                    if code != vm.recoveryCodes.last {
                        Divider().background(FMSTheme.borderLight)
                    }
                }
            }
            .background(FMSTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(FMSTheme.borderLight, lineWidth: 1)
            )
            
            Button {
                UIPasteboard.general.string = vm.recoveryCodes.joined(separator: "\n")
                bannerManager.show(type: .success, message: "Recovery codes copied to clipboard")
            } label: {
                HStack {
                    Image(systemName: "doc.on.doc")
                    Text("Copy All Codes")
                }
                .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(FMSTheme.amber)
            
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(FMSTheme.amber)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}
