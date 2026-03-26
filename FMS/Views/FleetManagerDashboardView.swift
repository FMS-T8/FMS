import SwiftUI
import CoreLocation
import MapKit

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

// MARK: - Home Tab Content
struct FleetManagerHomeTab: View {
  @State private var viewModel = FleetManagerHomeViewModel()
  @State private var navigateToLiveFleet = false
  @State private var navigateToProfile = false
  @State private var navigateToOrders = false
  @State private var sosExpanded: Bool = false
  @State private var alertsExpanded: Bool = false


  var body: some View {
    NavigationStack {
      ZStack {
        FMSTheme.backgroundPrimary.ignoresSafeArea()
        
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            // Header
            headerSection
            
            FleetStatusCard(
              activeCount: viewModel.activeVehicleCount,
              subtitle: "Vehicles in transit",
              onViewMap: {
                navigateToLiveFleet = true
              }
            )
            
            // Quick Actions
            QuickActionCard(
              icon: "shippingbox.fill",
              title: "Orders",
              subtitle:
                viewModel.pendingOrderCount > 0
              ? "\(viewModel.pendingOrderCount) pending orders"
              : "Manage fleet orders and dispatch",
              action: {
                navigateToOrders = true
              }
            )
            
            // Active SOS Alerts — repositioned below Orders
            if !viewModel.activeSOSAlerts.isEmpty {
              sosAlertsSection
            }
            
            // Recent Alerts Section
            alertsSection
          }
          .padding(.horizontal, 20)
          .padding(.top, 16)
        }
      }
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
        viewModel.startSOSPolling()
        Task {
          await viewModel.loadDashboardData()
        }
      }
      .onDisappear {
        viewModel.stopSOSPolling()
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

          Text("\(viewModel.activeSOSAlerts.count) Active SOS Alert\(viewModel.activeSOSAlerts.count == 1 ? "" : "s")")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(FMSTheme.alertRed)

          Spacer()

          if viewModel.activeSOSAlerts.count > 1 {
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
          ForEach(Array(viewModel.activeSOSAlerts.enumerated()), id: \.element.id) { index, alert in
            SOSAlertCard(
              viewModel: viewModel,
              alert: alert,
              isLatest: index == 0
            )
          }
        } else if let latest = viewModel.activeSOSAlerts.first {
          SOSAlertCard(
            viewModel: viewModel,
            alert: latest,
            isLatest: true
          )
          .id(latest.id)
        }
      }
      .padding(.top, 10)
    }
  }

  // MARK: - Header Section
  private var headerSection: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text("Welcome, \(viewModel.managerName)")
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
      Button {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
          alertsExpanded.toggle()
        }
      } label: {
        HStack {
          Text("Recent Alerts")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(FMSTheme.textPrimary)
          
          if !viewModel.recentAlerts.isEmpty {
            Text("\(viewModel.recentAlerts.count)")
              .font(.system(size: 11, weight: .bold))
              .foregroundStyle(FMSTheme.textSecondary)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(FMSTheme.borderLight)
              .clipShape(Capsule())
          }
          
          Spacer()
          
          Image(systemName: alertsExpanded ? "chevron.up" : "chevron.down")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(FMSTheme.textTertiary)
        }
      }
      .buttonStyle(.plain)

      if viewModel.recentAlerts.isEmpty {
        Text("No recent alerts.")
          .font(.system(size: 14))
          .foregroundStyle(FMSTheme.textTertiary)
          .padding(.top, 4)
      } else if alertsExpanded {
        VStack(spacing: 12) {
          ForEach(viewModel.recentAlerts) { alert in
            SwipeableAlertRow(
              alert: alert,
              title: alertTitle(for: alert),
              type: alertType(for: alert.type),
              timeAgo: timeAgoText(from: alert.createdAt),
              vehiclePlate: viewModel.vehiclePlates[alert.vehicleId ?? ""],
              onDelete: {
                Task { await viewModel.deleteNotification(id: alert.id) }
              }
            )
          }
        }
      } else if let latest = viewModel.recentAlerts.first {
        SwipeableAlertRow(
          alert: latest,
          title: alertTitle(for: latest),
          type: alertType(for: latest.type),
          timeAgo: timeAgoText(from: latest.createdAt),
          vehiclePlate: viewModel.vehiclePlates[latest.vehicleId ?? ""],
          onDelete: {
            Task { await viewModel.deleteNotification(id: latest.id) }
          }
        )
        .id(latest.id)
      }
    }
  }

  private func alertTitle(for alert: Notification) -> String {
    switch alert.type?.lowercased() {
    case "document_expiry": return "Document Expiry"
    case "geofence_entry": return "Geofence Entry"
    case "geofence_exit": return "Geofence Deviation"
    case "maintenance_due": return "Maintenance Due"
    case "crash_alert": return "Safety Alert"
    case "break_violation": return "Break Violation"
    default: return "System Alert"
    }
  }

  private func alertType(for type: String?) -> AlertType {
    switch type?.lowercased() {
    case "geofence_exit", "crash_alert", "break_violation":
      return .critical
    case "document_expiry", "maintenance_due":
      return .warning
    case "geofence_entry":
      return .info
    default:
      return .info
    }
  }

  private func timeAgoText(from date: Date?) -> String {
    guard let date = date else { return "Just now" }
    let seconds = Int(Date().timeIntervalSince(date))
    if seconds < 60 { return "Just now" }
    if seconds < 3600 { return "\(seconds / 60)m ago" }
    if seconds < 86400 { return "\(seconds / 3600)h ago" }
    return "\(seconds / 86400)d ago"
  }

  private var formattedDate: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE, MMMM d"
    return formatter.string(from: Date())
  }
}

// MARK: - SOS Alert Card

private struct SOSAlertCard: View {
  let viewModel: FleetManagerHomeViewModel
  let alert: SOSAlert
  var isLatest: Bool = false
  @Environment(\.openURL) private var openURL
  @State private var locationAddress: String = "Fetching location..."
  @State private var isResolving = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
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

      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Driver: \(viewModel.driverNames[alert.driverId] ?? alert.driverId)")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(FMSTheme.textPrimary)
          
          HStack(spacing: 4) {
            Image(systemName: "mappin.circle.fill")
              .font(.system(size: 10))
            Text(locationAddress)
              .font(.system(size: 11))
          }
          .foregroundStyle(FMSTheme.textSecondary)
          .padding(.top, 2)
        }

        Spacer()

        if let speed = alert.speed, speed > 0 {
          VStack(alignment: .trailing, spacing: 2) {
            Text("\(Int(speed))")
              .font(.system(size: 18, weight: .black))
              .foregroundStyle(FMSTheme.amber)
            Text("km/h")
              .font(.system(size: 10, weight: .bold))
              .foregroundStyle(FMSTheme.textTertiary)
          }
        }
      }

      // Actions
      HStack(spacing: 12) {
        // Call driver
        Button {
          if let phone = viewModel.driverPhones[alert.driverId], !phone.isEmpty {
            let cleanedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: "tel:\(cleanedPhone)") {
              openURL(url)
            }
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
        .disabled(
          viewModel.driverPhones[alert.driverId] == nil
            || viewModel.driverPhones[alert.driverId]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              ?? true
        )
        .opacity(
          (viewModel.driverPhones[alert.driverId] == nil
            || viewModel.driverPhones[alert.driverId]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              ?? true)
            ? 0.5 : 1.0)

        // Resolve Button
        Button {
          isResolving = true
          Task {
            await viewModel.resolveSOSAlert(id: alert.id)
            isResolving = false
          }
        } label: {
          if isResolving {
            ProgressView()
              .tint(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 10)
          } else {
            Text("Resolve SOS")
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 10)
          }
        }
        .background(FMSTheme.textTertiary)
        .cornerRadius(10)
        .buttonStyle(.plain)
      }
    }
    .padding(14)
    .background(statusColor.opacity(0.06))
    .cornerRadius(14)
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .stroke(statusColor.opacity(0.4), lineWidth: 1.5)
    )
    .task {
      await reverseGeocode()
    }
  }

  private func reverseGeocode() async {
    let location = CLLocation(latitude: alert.latitude, longitude: alert.longitude)
    guard let request = MKReverseGeocodingRequest(location: location) else { return }
    
    do {
      let mapItems = try await request.mapItems


      if let item = mapItems.first {
        if let address = item.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true) {
          self.locationAddress = address
        } else if let shortAddress = item.address?.shortAddress {
          self.locationAddress = shortAddress
        } else {
          self.locationAddress = "Unknown location"
        }
      }
    } catch {

      self.locationAddress = "Location unavailable"
    }
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

// MARK: - Swipeable Alert Row

private struct SwipeableAlertRow: View {
    let alert: Notification
    let title: String
    let type: AlertType
    let timeAgo: String
    let vehiclePlate: String?
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isSwiped: Bool = false
    @State private var willDelete: Bool = false
    @State private var didTriggerRevealHaptic: Bool = false
    
    private let buttonWidth: CGFloat = 80
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // 1. Alert Content (Bottom Layer with Gesture)
            AlertRow(
                title: title,
                subtitle: alert.message ?? "No details available",
                timeAgo: timeAgo,
                type: type,
                vehiclePlate: vehiclePlate
            )
            .offset(x: offset)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 15, coordinateSpace: .local)
                    .onChanged { value in
                        let swipe = value.translation.width
                        if swipe < 0 {
                            // Organic resistance
                            if swipe < -buttonWidth {
                                offset = -buttonWidth + (swipe + buttonWidth) * 0.35
                            } else {
                                offset = swipe
                            }
                            
                            // Subtle haptic when crossing the reveal threshold
                            if !didTriggerRevealHaptic && swipe < -buttonWidth / 2 {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred(intensity: 0.6)
                                didTriggerRevealHaptic = true
                            } else if swipe >= -buttonWidth / 2 {
                                didTriggerRevealHaptic = false
                            }
                        } else if isSwiped {
                            let newOffset = -buttonWidth + swipe
                            offset = newOffset > 0 ? 0 : newOffset
                        }
                    }
                    .onEnded { value in
                        let velocity = value.velocity.width
                        let shouldSwipe = value.translation.width < -buttonWidth / 2 || velocity < -300
                        didTriggerRevealHaptic = false
                        
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85, blendDuration: 0)) {
                            if shouldSwipe {
                                offset = -buttonWidth
                                isSwiped = true
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                            } else {
                                offset = 0
                                isSwiped = false
                            }
                        }
                    }
            )

            // 2. Delete Action (Top Layer when swiped)
            if offset < 0 {
                Button(role: .destructive) {
                    deleteAction()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("Clear")
                            .font(.system(size: 10, weight: .black))
                    }
                    .foregroundStyle(.white)
                    .frame(width: buttonWidth - 8)
                    .frame(maxHeight: .infinity)
                    .background(FMSTheme.alertRed)
                    .cornerRadius(12)
                    .padding(.vertical, 8)
                    .padding(.trailing, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .zIndex(1)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)).animation(.spring(response: 0.3, dampingFraction: 0.8)),
                    removal: .opacity.combined(with: .scale(scale: 0.8))
                ))
            }
        }
        .scaleEffect(willDelete ? 0.9 : 1.0)
        .opacity(willDelete ? 0 : 1)
    }
    
    private func deleteAction() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            willDelete = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDelete()
        }
    }
}
