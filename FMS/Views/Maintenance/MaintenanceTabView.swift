import SwiftUI

public struct MaintenanceTabView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var selectedTab = 0

    // Single source of truth — shared across Dashboard + Defects
    @State private var woStore      = WorkOrderStore()
    @State private var defectStore  = DefectStore()

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            MaintenanceDashboardView(woStore: woStore)
                .tabItem {
                    Label("Dashboard", systemImage: "squares.below.rectangle")
                }
                .tag(0)

            DefectsView(woStore: woStore, defectStore: defectStore)
                .tabItem {
                    Label("Defects", systemImage: "exclamationmark.triangle")
                }
                .tag(1)

            InventoryView()
                .tabItem {
                    Label("Inventory", systemImage: "shippingbox")
                }
                .tag(2)

            ProfileTabView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
                .tag(3)
        }
        .tint(FMSTheme.amberDark)
    }
}

// MARK: - Profile Tab
public struct ProfileTabView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.colorScheme) private var colorScheme

    public var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? FMSTheme.obsidian : FMSTheme.backgroundPrimary).ignoresSafeArea()

                VStack(spacing: 0) {
                    FMSTitleRow(title: "My Profile")
                    Divider().opacity(0.35)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            profileHeaderCard
                            basicInfoCard
                            preferencesCard
                            logoutButton
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var profileHeaderCard: some View {
        MaintProfileCard {
            VStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(FMSTheme.amber.opacity(0.18))
                        .frame(width: 84, height: 84)
                    Text(avatarInitials)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(FMSTheme.amber)
                }

                VStack(spacing: 4) {
                    Text(authViewModel.currentUser?.name ?? "Maintenance Tech")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(FMSTheme.textPrimary)

                    Text(authViewModel.currentUser?.role.capitalized ?? "Fleet Maintenance")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(FMSTheme.amber)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(FMSTheme.amber.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text("ID · \((authViewModel.currentUser?.id ?? "N/A").prefix(8).uppercased())")
                    .font(.system(size: 13))
                    .foregroundStyle(FMSTheme.textSecondary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private var basicInfoCard: some View {
        MaintProfileCard {
            VStack(alignment: .leading, spacing: 14) {
                MaintProfileSectionHeader(title: "Basic Information")
                Divider().background(FMSTheme.borderLight)
                MaintProfileInfoRow(icon: "envelope.fill", label: "Email", value: authViewModel.currentUser?.email ?? "tech@fleetms.com")
                MaintProfileInfoRow(icon: "phone.fill",    label: "Phone", value: authViewModel.currentUser?.phone ?? "Not Provided")
                MaintProfileInfoRow(icon: "building.2.fill", label: "Department", value: authViewModel.currentUser?.role.capitalized ?? "Maintenance")
            }
        }
    }

    private var preferencesCard: some View {
        MaintProfileCard {
            VStack(alignment: .leading, spacing: 14) {
                MaintProfileSectionHeader(title: "System Preferences")
                Divider().background(FMSTheme.borderLight)
                
                HStack {
                    Text("Theme Appearance")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(FMSTheme.textPrimary)
                    Spacer()
                    Text("System")
                        .font(.system(size: 15))
                        .foregroundStyle(FMSTheme.textSecondary)
                }
                
                Divider().background(FMSTheme.borderLight)

                HStack {
                    Text("Notifications")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(FMSTheme.textPrimary)
                    Spacer()
                    Toggle("", isOn: .constant(true))
                        .tint(FMSTheme.amber)
                }
            }
        }
    }

    private var logoutButton: some View {
        Button {
            Task {
                await authViewModel.logout()
            }
        } label: {
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

    private var avatarInitials: String {
        let name = authViewModel.currentUser?.name ?? "Maintenance Tech"
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Reusable UI Components
private struct MaintProfileCard<Content: View>: View {
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

private struct MaintProfileSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(FMSTheme.textPrimary)
    }
}

private struct MaintProfileInfoRow: View {
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

#Preview {
    MaintenanceTabView()
        .environment(AuthViewModel())
}
