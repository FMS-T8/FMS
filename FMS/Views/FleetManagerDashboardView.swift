import SwiftUI
import Supabase

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
                MaintenanceManagerView()
            }

            // Reports Tab
            FMSTabItem(id: "reports", title: "Reports", icon: "chart.bar.xaxis") {
                ReportsHubView()
            }
        }
    }
}

// MARK: - RichTripAlert
struct RichTripAlert: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let timeAgo: String
    let type: AlertType
    let timestamp: Date
}

// MARK: - Home Tab Content
struct FleetManagerHomeTab: View {
    @State private var navigateToLiveFleet = false
    @State private var navigateToProfile = false
    @State private var navigateToOrders = false
    @State private var activeSOSAlerts: [SOSAlert] = []
    @State private var sosPollingTimer: Timer?
    @State private var sosExpanded: Bool = false

    // Mock data
    private let managerName = "Manager"
    private let activeVehicles = 14
    private let pendingOrders = 12

    @State private var recentAlerts: [RichTripAlert] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerSection

                    // Active SOS Alerts
                    if !activeSOSAlerts.isEmpty {
                        sosAlertsSection
                    }

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
                        title: "Orders",
                        subtitle: "Manage fleet orders and dispatch",
                        action: {
                            navigateToOrders = true
                        }
                    )

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
            .navigationDestination(isPresented: $navigateToOrders) {
                OrdersListView()
            }
            .onAppear {
                startSOSPolling()
            }
            .onDisappear {
                sosPollingTimer?.invalidate()
                sosPollingTimer = nil
            }
        }
    }

    // MARK: - SOS Alerts Section
    private var sosAlertsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Counter row — always visible
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    sosExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sos")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(FMSTheme.alertRed)
                        .cornerRadius(8)

                    Text("\(activeSOSAlerts.count) Active SOS Alert\(activeSOSAlerts.count == 1 ? "" : "s")")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(FMSTheme.alertRed)

                    Spacer()

                    if activeSOSAlerts.count > 1 {
                        Image(systemName: sosExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(FMSTheme.alertRed)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(FMSTheme.alertRed.opacity(0.08))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(FMSTheme.alertRed.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Alert cards
            VStack(spacing: 10) {
                if sosExpanded {
                    ForEach(Array(activeSOSAlerts.enumerated()), id: \.element.id) { index, alert in
                        SOSAlertCard(
                            alert: alert,
                            isLatest: index == 0
                        )
                    }
                } else if let latest = activeSOSAlerts.first {
                    SOSAlertCard(
                        alert: latest,
                        isLatest: true
                    )
                }
            }
            .padding(.top, 10)
        }
    }

    // MARK: - SOS Polling
    private func startSOSPolling() {
        fetchSOSAlerts()
        fetchRecentAlerts()
        sosPollingTimer?.invalidate()
        sosPollingTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            Task { @MainActor in
                fetchSOSAlerts()
                fetchRecentAlerts()
            }
        }
    }

    private func fetchSOSAlerts() {
        Task {
            do {
                let response = try await SupabaseService.shared.client
                    .from("sos_alerts")
                    .select()
                    .eq("status", value: SOSAlertStatus.active.rawValue)
                    .order("timestamp", ascending: false)
                    .limit(10)
                    .execute()

                let alerts = try JSONDecoder.supabase().decode([SOSAlert].self, from: response.data)
                activeSOSAlerts = alerts
            } catch {
                print("[FMS] fetchSOSAlerts failed: \(error)")
            }
        }
    }

    private func fetchRecentAlerts() {
        Task {
            do {
                var query = SupabaseService.shared.client
                    .from("vehicle_events")
                    .select()
                    .in("event_type", values: ["trip_start", "trip_end"])
                
                let currentDeleted = Set(UserDefaults.standard.stringArray(forKey: "deletedTripAlertIDs") ?? [])
                if !currentDeleted.isEmpty {
                    let formattedIDs = "(\(Array(currentDeleted).joined(separator: ",")))"
                    query = query.not("id", operator: .in, value: formattedIDs)
                }
                
                let response = try await query
                    .order("timestamp", ascending: false)
                    .limit(10)
                    .execute()
                
                let events = try JSONDecoder.supabase().decode([VehicleEvent].self, from: response.data)
                
                var fetchedAlerts: [RichTripAlert] = []
                for event in events {
                    let isStart = event.eventType == .tripStart
                    let title = isStart ? "Trip Started" : "Trip Ended"
                    
                    var subtitle = "Vehicle \(String(event.vehicleID.prefix(6))) \(isStart ? "started a" : "completed its") trip."
                    
                    if let vId = UUID(uuidString: event.vehicleID) {
                        struct MockVehicle: Decodable { let plate_number: String }
                        if let vehicle: [MockVehicle] = try? await SupabaseService.shared.client.from("vehicles").select("plate_number").eq("id", value: vId).execute().value, let first = vehicle.first {
                            subtitle = "Vehicle \(first.plate_number) \(isStart ? "started a" : "completed its") trip."
                        }
                    }
                    
                    let seconds = Int(Date().timeIntervalSince(event.timestamp))
                    let timeAgo: String
                    if seconds < 60 { timeAgo = "Just now" }
                    else if seconds < 3600 { timeAgo = "\(seconds / 60)m ago" }
                    else { timeAgo = "\(seconds / 3600)h ago" }
                    
                    fetchedAlerts.append(RichTripAlert(
                        id: event.id,
                        title: title,
                        subtitle: subtitle,
                        timeAgo: timeAgo,
                        type: .info,
                        timestamp: event.timestamp
                    ))
                }
                
                await MainActor.run {
                    let currentDeleted = Set(UserDefaults.standard.stringArray(forKey: "deletedTripAlertIDs") ?? [])
                    fetchedAlerts.removeAll { currentDeleted.contains($0.id) }
                    self.recentAlerts = fetchedAlerts
                }
            } catch {
                print("[FMS] fetchRecentAlerts failed: \(error)")
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

            if recentAlerts.isEmpty {
                Text("No recent alerts.")
                    .font(.system(size: 14))
                    .foregroundStyle(FMSTheme.textTertiary)
                    .padding(.vertical, 10)
            } else {
                ForEach(recentAlerts) { alert in
                    SwipeToDeleteWrapper(onDelete: {
                        var currentDeleted = Set(UserDefaults.standard.stringArray(forKey: "deletedTripAlertIDs") ?? [])
                        currentDeleted.insert(alert.id)
                        UserDefaults.standard.set(Array(currentDeleted), forKey: "deletedTripAlertIDs")
                        
                        withAnimation {
                            recentAlerts.removeAll { $0.id == alert.id }
                        }
                    }) {
                        AlertRow(
                            title: alert.title,
                            subtitle: alert.subtitle,
                            timeAgo: alert.timeAgo,
                            type: alert.type
                        )
                    }
                }
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
}

// MARK: - Swipe To Delete Helper
private struct SwipeToDeleteWrapper<Content: View>: View {
    let content: Content
    let onDelete: () -> Void
    @State private var offset: CGFloat = 0

    init(onDelete: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onDelete = onDelete
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete Background
            Rectangle()
                .fill(FMSTheme.alertRed)
                .cornerRadius(12)
            
            Image(systemName: "trash")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .padding(.trailing, 20)
            
            // Content
            content
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width < 0 {
                                offset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            if value.translation.width < -80 {
                                withAnimation {
                                    offset = -1000
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onDelete()
                                }
                            } else {
                                withAnimation {
                                    offset = 0
                                }
                            }
                        }
                )
        }
    }
}

// MARK: - SOS Alert Card

private struct SOSAlertCard: View {
    let alert: SOSAlert
    var isLatest: Bool = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(statusColor)

                Text(statusLabel)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(statusColor)

                if isLatest && alert.status == .active {
                    Text("LATEST")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(FMSTheme.obsidian)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(FMSTheme.amber)
                        .cornerRadius(4)
                }

                Spacer()

                Text(timeAgoText)
                    .font(.system(size: isLatest ? 13 : 12, weight: isLatest ? .bold : .medium))
                    .foregroundStyle(isLatest ? FMSTheme.amber : FMSTheme.textTertiary)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Driver: \(alert.driverId)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FMSTheme.textPrimary)

                    Text("Vehicle: \(alert.vehicleId)")
                        .font(.system(size: 12))
                        .foregroundStyle(FMSTheme.textSecondary)

                    if let speed = alert.speed, speed > 0 {
                        Text(String(format: "Speed: %.0f km/h", speed))
                            .font(.system(size: 12))
                            .foregroundStyle(FMSTheme.textSecondary)
                    }
                }

                Spacer()

                VStack(spacing: 2) {
                    Text(String(format: "%.4f", alert.latitude))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(FMSTheme.textSecondary)
                    Text(String(format: "%.4f", alert.longitude))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(FMSTheme.textSecondary)
                }
            }

            // Call driver
            Button {
                if let url = URL(string: "tel:+919425003856") {
                    openURL(url)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Call Driver")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(FMSTheme.alertGreen)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(statusColor.opacity(0.06))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(statusColor.opacity(0.4), lineWidth: 1.5)
        )
    }

    private var statusColor: Color {
        switch alert.status {
        case .active: return FMSTheme.alertRed
        case .acknowledged: return FMSTheme.alertOrange
        case .resolved: return FMSTheme.alertGreen
        case .cancelled: return FMSTheme.textTertiary
        }
    }

    private var statusLabel: String {
        switch alert.status {
        case .active: return "EMERGENCY SOS"
        case .acknowledged: return "SOS — ACKNOWLEDGED"
        case .resolved: return "SOS — RESOLVED"
        case .cancelled: return "SOS — CANCELLED"
        }
    }

    private var timeAgoText: String {
        let seconds = Int(Date().timeIntervalSince(alert.timestamp))
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }
}
