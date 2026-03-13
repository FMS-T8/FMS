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

                VStack(spacing: 28) {
                    Spacer()

                    // Avatar
                    ZStack {
                        Circle()
                            .fill(FMSTheme.amber.opacity(0.15))
                            .frame(width: 100, height: 100)
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(FMSTheme.amberDark)
                    }

                    VStack(spacing: 6) {
                        Text(authViewModel.currentUser?.name ?? "Maintenance Tech")
                            .font(.title2.weight(.bold))
                            .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                        Text(authViewModel.currentUser?.role.capitalized ?? "Fleet Maintenance Division")
                            .font(.subheadline)
                            .foregroundColor(FMSTheme.textSecondary)
                    }

                    // Info Rows
                    VStack(spacing: 1) {
                        ProfileRow(icon: "envelope", label: "Email", value: authViewModel.currentUser?.email ?? "tech@fleetms.com")
                        ProfileRow(icon: "phone", label: "Phone", value: authViewModel.currentUser?.phone ?? "Not Provided")
                        ProfileRow(icon: "building.2", label: "Department", value: authViewModel.currentUser?.role.capitalized ?? "Maintenance")
                        ProfileRow(icon: "tag", label: "Account ID", value: String((authViewModel.currentUser?.id ?? "N/A").prefix(8).uppercased()))
                    }
                    .cornerRadius(14)
                    .padding(.horizontal)

                    Spacer()

                    Button(role: .destructive) {
                        withAnimation { authViewModel.logout() }
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Logout")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(FMSTheme.alertRed.opacity(0.1))
                        .foregroundColor(FMSTheme.alertRed)
                        .cornerRadius(14)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct ProfileRow: View {
    let icon: String
    let label: String
    let value: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(FMSTheme.amberDark)
                .frame(width: 32, height: 32)
                .background(FMSTheme.amber.opacity(0.12))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(FMSTheme.textSecondary)
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(colorScheme == .dark
                    ? Color(red: 28/255, green: 28/255, blue: 30/255)
                    : FMSTheme.cardBackground)
    }
}

#Preview {
    MaintenanceTabView()
        .environment(AuthViewModel())
}
