import SwiftUI

public struct FleetManagerDashboardView: View {
    public init() {}
    
    public var body: some View {
        FMSTabShell {
            FMSTabItem(id: "home", title: "Home", icon: "house.fill") {
                FleetManagerHomeTab()
            }
            FMSTabItem(id: "fleet", title: "Fleet", icon: "truck.box.fill") {
                // TODO: Fleet tab
                Text("Fleet")
            }
            FMSTabItem(id: "drivers", title: "Drivers", icon: "person.2.fill") {
                // TODO: Drivers tab
                Text("Drivers")
            }
        }
    }
}

// MARK: - Home Tab Content

struct FleetManagerHomeTab: View {
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection
                
                // Fleet Status Card
                FleetStatusCard(
                    activeCount: activeVehicles,
                    subtitle: "Vehicles in transit",
                    onViewMap: {
                        // Navigate to map
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
                
                // Recent Alerts Section
                alertsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(FMSTheme.backgroundPrimary)
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
            
            // Profile avatar
            ZStack {
                Circle()
                    .fill(FMSTheme.borderLight)
                    .frame(width: 48, height: 48)
                
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(FMSTheme.textTertiary)
            }
        }
    }
    
    // MARK: - Alerts Section
    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Alerts")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)
            
            ForEach(Array(alerts.enumerated()), id: \.offset) { index, alert in
                AlertRow(
                    title: alert.title,
                    subtitle: alert.subtitle,
                    timeAgo: alert.timeAgo,
                    type: alert.type
                )
            }
        }
    }
    
    // MARK: - Helpers
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
}

#Preview {
    FleetManagerDashboardView()
}
