import SwiftUI

public struct FleetManagerDashboardView: View {
    public init() {}
    
    public var body: some View {
        FMSTabShell {
            
            // Home Tab
            FMSTabItem(id: "home", title: "Home", icon: "house.fill") {
                FleetManagerHomeTab()
            }
            
            // Fleet Tab
            FMSTabItem(id: "fleet", title: "Fleet", icon: "truck.box.fill") {
                FleetManagementView()
            }
            
            // Drivers Tab
            FMSTabItem(id: "drivers", title: "Drivers", icon: "person.2.fill") {
                DriversView()
            }
            // Maintenance Tab
            FMSTabItem(id: "maintenance", title: "Maintenance", icon: "wrench.and.screwdriver.fill") {
                Text("Maintenance")
            }
        }
    }
}

// MARK: - Home Tab Content
struct FleetManagerHomeTab: View {
    @State private var navigateToLiveFleet = false
    @State private var navigateToPreTrip = false
    @State private var navigateToPostTrip = false
    @State private var navigateToProfile = false

    // Mock data
    private let managerName = "Manager"
    private let activeVehicles = 14
    private let pendingOrders = 12

    private let alerts: [(title: String, subtitle: String, timeAgo: String, type: AlertType)] = [
        ("Tyre pressure warning", "Truck #402 reported low pressure in rear-left tyre.", "12m ago", .warning),
        ("Driver break scheduled", "Driver David R. is reaching mandatory rest limit in 15 mins.", "45m ago", .info),
        ("Geofence deviation", "Truck #109 exited the designated route area in North District.", "1h ago", .critical)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerSection

                    // Fleet Status Card
                    FleetStatusCard(
                        activeCount: activeVehicles,
                        subtitle: "Vehicles in transit",
                        onViewMap: {
                            navigateToLiveFleet = true
                        }
                    )

                    // Quick Actions
                    QuickActionCard(
                        icon: "shippingbox.fill",
                        title: "Pending Orders",
                        subtitle: "\(pendingOrders) orders awaiting dispatch",
                        action: {
                            // Navigate to orders
                        }
                    )

                    // Inspection Actions
                    inspectionSection

                    // Recent Alerts Section
                    alertsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(FMSTheme.backgroundPrimary)
            .navigationDestination(isPresented: $navigateToLiveFleet) {
                LiveVehicleDashboardView()
            }
            .navigationDestination(isPresented: $navigateToProfile) {
                ManagerProfileView()
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome, \(managerName)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(FMSTheme.textPrimary)
                
                Text(formattedDate)
                    .font(.system(size: 14))
                    .foregroundStyle(FMSTheme.textSecondary)
            }
            
            Spacer()
            
            Button {
                navigateToProfile = true
            } label: {
                ZStack {
                    Circle()
                        .fill(FMSTheme.borderLight)
                        .frame(width: 48, height: 48)
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(FMSTheme.amber)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Alerts Section
    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Alerts")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)
            
            ForEach(alerts.indices, id: \.self) { index in
                let alert = alerts[index]
                AlertRow(
                    title: alert.title,
                    subtitle: alert.subtitle,
                    timeAgo: alert.timeAgo,
                    type: alert.type
                )
            }
        }
    }
    
    // MARK: - Inspection Section
    private var inspectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vehicle Inspections")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)

            QuickActionCard(
                icon: "checkmark.shield.fill",
                title: "Pre-trip Inspection",
                subtitle: "Complete before starting a route",
                action: { navigateToPreTrip = true }
            )

            QuickActionCard(
                icon: "flag.checkered",
                title: "Post-trip Inspection",
                subtitle: "Log vehicle condition after route",
                action: { navigateToPostTrip = true }
            )
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
}
