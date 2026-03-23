import SwiftUI

public struct FMSMaintenanceSummaryCard: View {
    public let title: String
    public let mainCount: Int
    public let mainLabel: String
    public let subtitle: String
    public let showWarning: Bool
    public let subItems: [SummarySubItemData]
    
    public init(title: String, mainCount: Int, mainLabel: String, subtitle: String, showWarning: Bool = false, subItems: [SummarySubItemData] = []) {
        self.title = title
        self.mainCount = mainCount
        self.mainLabel = mainLabel
        self.subtitle = subtitle
        self.showWarning = showWarning
        self.subItems = subItems
    }
    
    public struct SummarySubItemData: Identifiable {
        public let id = UUID()
        public let icon: String
        public let count: Int
        public let label: String
        
        public init(icon: String, count: Int, label: String) {
            self.icon = icon
            self.count = count
            self.label = label
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(Color.black.opacity(0.4))
                    .kerning(1)
                
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(mainCount) \(mainLabel)")
                        .font(.system(size: 34, weight: .black))
                        .foregroundColor(.black)
                    
                    if showWarning && mainCount > 0 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundColor(.black)
                    }
                }
                
                Text(subtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.black.opacity(0.7))
                
                if !subItems.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(subItems) { item in
                            HStack(spacing: 6) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 10))
                                Text("\(item.count) \(item.label)")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.1))
                            .cornerRadius(12)
                            .foregroundColor(.black)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    FMSTheme.amber
                    
                    // Maintenance Watermark (Single Icon)
                    Image(systemName: "wrench.adjustable.fill")
                        .font(.system(size: 160))
                        .rotationEffect(.degrees(-15))
                        .foregroundColor(.black.opacity(0.05))
                        .offset(x: 130, y: 30)
                }
            )
            .cornerRadius(24)
        }
    }
}

public struct StatusSummaryCard: View {
    let title: String
    let count: Int
    let color: Color
    
    public init(title: String, count: Int, color: Color) {
        self.title = title
        self.count = count
        self.color = color
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            Text("\(count)")
                .font(.system(size: 24, weight: .black))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(FMSTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(FMSTheme.cardBackground)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.3), lineWidth: 1))
    }
}

public struct VehicleServiceCard: View {
    let vehicle: Vehicle
    var isWorkOrderCreated: Bool = false
    
    public init(vehicle: Vehicle, isWorkOrderCreated: Bool = false) {
        self.vehicle = vehicle
        self.isWorkOrderCreated = isWorkOrderCreated
    }
    
    public var body: some View {
        let settingsStore = MaintenanceSettingsStore.shared
        let status = MaintenancePredictionService.calculateStatus(
            for: vehicle, 
            defaultKm: settingsStore.intervalKmDouble
        )
        let reason = MaintenancePredictionService.getStatusReason(
            for: vehicle, 
            defaultKm: settingsStore.intervalKmDouble
        )
        
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.plateNumber)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(FMSTheme.textPrimary)
                    
                    Text("\(vehicle.manufacturer ?? "") \(vehicle.model ?? "")")
                        .font(.system(size: 14))
                        .foregroundColor(FMSTheme.textSecondary)
                }
                
                Spacer()
                
                // Status Badge (Top Right)
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor(status))
                        .frame(width: 6, height: 6)
                    Text(status.rawValue.uppercased())
                        .font(.system(size: 10, weight: .black))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(statusColor(status).opacity(0.12))
                .foregroundColor(statusColor(status))
                .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(FMSTheme.textTertiary)
                    Text(reason)
                        .font(.system(size: 13))
                        .foregroundColor(FMSTheme.textSecondary)
                        .lineLimit(1)
                }
                
                let progress = calculateProgress(vehicle, settingsStore: settingsStore)
                let safeProgress = progress.isFinite ? min(max(progress, 0), 1) : 0
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("MILEAGE PROGRESS")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(FMSTheme.textTertiary)
                            .kerning(0.5)
                        Spacer()
                        Text("\(Int(safeProgress * 100))%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(FMSTheme.textSecondary)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(FMSTheme.cardBackground.opacity(0.8)).frame(height: 6)
                            Capsule()
                                .fill(statusColor(status))
                                .frame(width: geo.size.width * CGFloat(safeProgress), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.top, 4)
            }
            
            HStack(spacing: 12) {
                // Secondary Info
                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 10))
                    let drivenKm = Int((vehicle.odometer ?? 0) - (vehicle.lastServiceOdometer ?? 0))
                    Text("\(max(0, drivenKm)) km")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(FMSTheme.textSecondary)
                
                Spacer()
                
                // Action Button Section
                if isWorkOrderCreated {
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.system(size: 10))
                            Text("WO CREATED")
                                .font(.system(size: 11, weight: .black))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(FMSTheme.amber.opacity(0.12))
                        .foregroundColor(FMSTheme.amberDark)
                        .cornerRadius(12)
                    }
                } else {
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.system(size: 12))
                            Text("Service")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(FMSTheme.amber.opacity(0.9))
                        .foregroundColor(.black)
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding(20)
        .background(FMSTheme.cardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isWorkOrderCreated ? FMSTheme.amber.opacity(0.5) : FMSTheme.borderLight.opacity(0.5), lineWidth: 1)
        )
    }
    
    private func statusColor(_ status: MaintenanceStatus) -> Color {
        switch status {
        case .ok:       return FMSTheme.alertGreen
        case .upcoming: return FMSTheme.alertOrange
        case .due:      return FMSTheme.alertRed
        }
    }
    
    private func calculateProgress(_ vehicle: Vehicle, settingsStore: MaintenanceSettingsStore) -> Double {
        let intervalKm = vehicle.serviceIntervalKm ?? settingsStore.intervalKmDouble
        let currentOdo = vehicle.odometer ?? 0
        let lastOdo = vehicle.lastServiceOdometer ?? 0
        let distanceSinceLast = currentOdo - lastOdo
        return distanceSinceLast / intervalKm
    }
}

public struct DashWOCard: View {
    public let order: WOItem
    public let cardBg: Color
    @Environment(\.colorScheme) private var colorScheme
    
    public init(woItem: WOItem, background: Color) {
        self.order = woItem
        self.cardBg = background
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 3)
                .fill(order.priority.color)
                .frame(width: 4)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 10) {
                // Header row
                HStack(spacing: 10) {
                    // Icon block
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(order.priority.color.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 15))
                            .foregroundColor(order.priority.color)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        let parts = order.vehicle.components(separatedBy: " · ")
                        let plate = parts.count > 1 ? parts.last! : order.vehicle
                        let makeModel = parts.first ?? order.vehicle
                        
                        Text(plate)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                        Text(makeModel)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    Spacer()
                    // Status pill
                    HStack(spacing: 4) {
                        Circle().fill(order.status.color).frame(width: 6, height: 6)
                        Text(order.status.rawValue.capitalized)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(order.status.color)
                    }
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(order.status.color.opacity(0.1))
                    .clipShape(Capsule())
                }

                // Description
                Text(order.description)
                    .font(.system(size: 13))
                    .foregroundColor(FMSTheme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Footer
                HStack {
                    Label(order.priority.rawValue.capitalized + " Priority",
                          systemImage: "flag.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(order.priority.color)
                    Spacer()
                    if let cost = order.estimatedCost {
                        Text("Est. $\(Int(cost))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(FMSTheme.textSecondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(FMSTheme.textTertiary)
                }
            }
            .padding(14)
        }
        .background(cardBg)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(FMSTheme.borderLight.opacity(colorScheme == .dark ? 0.15 : 1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}
