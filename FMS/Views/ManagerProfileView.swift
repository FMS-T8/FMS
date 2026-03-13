//
//  ManagerProfileView.swift
//  FMS
//
//  Created by Nikunj Mathur on 13/03/26.
//

import SwiftUI

// MARK: - ManagerProfileView

struct ManagerProfileView: View {
    @Environment(BannerManager.self) private var bannerManager
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var vm = ManagerProfileViewModel()
    @State private var showChangePassword = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                profileHeaderCard
                basicInfoCard
                securityCard
                preferencesCard
                fleetStatsCard
                logoutButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(FMSTheme.backgroundPrimary)
        .navigationTitle("My Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.loadAll() }
        .overlay {
            if vm.isLoading {
                loadingOverlay
            }
        }
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordSheet(vm: vm, bannerManager: bannerManager)
        }
    }

    // MARK: - Profile Header

    private var profileHeaderCard: some View {
        ProfileCard {
            VStack(spacing: 12) {
                // Avatar with initials
                ZStack {
                    Circle()
                        .fill(FMSTheme.amber.opacity(0.18))
                        .frame(width: 84, height: 84)
                    Text(avatarInitials)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(FMSTheme.amber)
                }

                VStack(spacing: 4) {
                    Text(vm.name.isEmpty ? "—" : vm.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(FMSTheme.textPrimary)

                    Text(vm.role.isEmpty ? "Fleet Manager" : vm.role.capitalized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(FMSTheme.amber)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(FMSTheme.amber.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text("ID · \(vm.employeeId)")
                    .font(.system(size: 13))
                    .foregroundStyle(FMSTheme.textSecondary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Basic Info

    private var basicInfoCard: some View {
        ProfileCard {
            VStack(alignment: .leading, spacing: 14) {
                ProfileSectionHeader(title: "Basic Information")
                Divider().background(FMSTheme.borderLight)
                ProfileInfoRow(icon: "envelope.fill",   label: "Email",  value: vm.email.isEmpty ? "—" : vm.email)
                ProfileInfoRow(icon: "phone.fill",      label: "Phone",  value: vm.phone.isEmpty ? "—" : vm.phone)
            }
        }
    }

    // MARK: - Security

    private var securityCard: some View {
        ProfileCard {
            VStack(alignment: .leading, spacing: 14) {
                ProfileSectionHeader(title: "Security")
                Divider().background(FMSTheme.borderLight)

                // Change Password
                Button {
                    showChangePassword = true
                } label: {
                    HStack {
                        Text("Change Password")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(FMSTheme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(FMSTheme.textTertiary)
                    }
                }

                Divider().background(FMSTheme.borderLight)

                // 2FA Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Two-Factor Authentication")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(FMSTheme.textPrimary)
                        Text("Coming soon!")
                            .font(.system(size: 12))
                            .foregroundStyle(FMSTheme.textTertiary)
                    }
                    Spacer()
                    Toggle("", isOn: $vm.isTwoFactorEnabled)
                        .tint(FMSTheme.amber)
                        .onChange(of: vm.isTwoFactorEnabled) {
                            Task { await vm.savePreferences() }
                        }
                }
            }
        }
    }

    // MARK: - System Preferences

    private var preferencesCard: some View {
        ProfileCard {
            VStack(alignment: .leading, spacing: 14) {
                ProfileSectionHeader(title: "System Preferences")
                Divider().background(FMSTheme.borderLight)

                // Map Preference Picker
                HStack {
                    Text("Map Style")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(FMSTheme.textPrimary)
                    Spacer()
                    Picker("Map Style", selection: $vm.mapPreference) {
                        ForEach(MapPreference.allCases) { pref in
                            Text(pref.displayName).tag(pref)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(FMSTheme.amber)
                    .onChange(of: vm.mapPreference) {
                        Task { await vm.savePreferences() }
                    }
                }

                Divider().background(FMSTheme.borderLight)

                // Distance Units Picker
                HStack {
                    Text("Distance Units")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(FMSTheme.textPrimary)
                    Spacer()
                    Picker("Units", selection: $vm.distanceUnit) {
                        ForEach(DistanceUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(FMSTheme.amber)
                    .onChange(of: vm.distanceUnit) {
                        Task { await vm.savePreferences() }
                    }
                }
            }
        }
    }

    // MARK: - Fleet Stats

    private var fleetStatsCard: some View {
        ProfileCard {
            VStack(alignment: .leading, spacing: 14) {
                ProfileSectionHeader(title: "Fleet Overview")
                Divider().background(FMSTheme.borderLight)

                HStack(spacing: 0) {
                    FleetStatCell(value: "\(vm.fleetSize)",        label: "Vehicles")
                    statDivider
                    FleetStatCell(value: "\(vm.driverCount)",      label: "Drivers")
                    statDivider
                    FleetStatCell(value: "\(vm.maintenanceCount)", label: "Maintenance")
                }
            }
        }
    }

    private var statDivider: some View {
        Rectangle()
            .fill(FMSTheme.borderLight)
            .frame(width: 1)
            .padding(.vertical, 8)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            FMSTheme.backgroundPrimary.opacity(0.7)
            ProgressView()
                .progressViewStyle(.circular)
                .tint(FMSTheme.amber)
                .scaleEffect(1.4)
        }
        .ignoresSafeArea()
    }

    // MARK: - Logout

    private var logoutButton: some View {
        Button {
            Task {
                await authViewModel.logout()
            }
        }label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 15, weight: .semibold))
                Text("Log Out")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(FMSTheme.alertRed)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(FMSTheme.alertRed.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Helpers

    private var avatarInitials: String {
        let parts = vm.name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(vm.name.prefix(2)).uppercased()
    }
}

// MARK: - Change Password Sheet

private struct ChangePasswordSheet: View {
    @Bindable var vm: ManagerProfileViewModel
    var bannerManager: BannerManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ProfileCard {
                    VStack(alignment: .leading, spacing: 14) {
                        PasswordField(label: "Current Password",    text: $vm.currentPassword)
                        Divider().background(FMSTheme.borderLight)
                        PasswordField(label: "New Password",         text: $vm.newPassword)
                        Divider().background(FMSTheme.borderLight)
                        PasswordField(label: "Confirm New Password", text: $vm.confirmPassword)

                        if let err = vm.passwordError {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundStyle(FMSTheme.alertRed)
                                .padding(.top, 4)
                        }
                    }
                }
                .padding(.horizontal, 20)

                Button {
                    Task {
                        await vm.changePassword(bannerManager: bannerManager)
                        if vm.passwordSuccess { dismiss() }
                    }
                } label: {
                    if vm.isChangingPassword {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        Text("Update Password")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                }
                .background(FMSTheme.amber)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
                .disabled(vm.isChangingPassword)
            }
            .padding(.top, 8)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(FMSTheme.backgroundPrimary)
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Reusable Subcomponents

private struct ProfileCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FMSTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: FMSTheme.shadowSmall, radius: 6, x: 0, y: 2)
    }
}

private struct ProfileSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(FMSTheme.textPrimary)
    }
}

private struct ProfileInfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(FMSTheme.amber)
                .frame(width: 22, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(FMSTheme.textTertiary)
                    .textCase(.uppercase)
                    .kerning(0.4)
                Text(value)
                    .font(.system(size: 15))
                    .foregroundStyle(FMSTheme.textPrimary)
            }
        }
    }
}

private struct FleetStatCell: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(FMSTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

private struct PasswordField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        SecureField(label, text: $text)
            .font(.system(size: 15))
            .foregroundStyle(FMSTheme.textPrimary)
            .tint(FMSTheme.amber)
    }
}
