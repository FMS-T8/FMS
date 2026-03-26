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
    var showForecast: Bool = false
    var showMileage: Bool = true
    var showBudget: Bool = true
    var showSecondaryInfo: Bool = true
    
    // Injected data to avoid redundant fetches
    var initialBudgetStatus: BudgetService.BudgetStatus? = nil
    var initialForecast: MaintenancePredictionService.MaintenanceForecast? = nil
    
    @State private var budgetStatus: BudgetService.BudgetStatus? = nil
    @State private var forecast: MaintenancePredictionService.MaintenanceForecast? = nil
    
    public init(
        vehicle: Vehicle, 
        isWorkOrderCreated: Bool = false,
        showForecast: Bool = false,
        showMileage: Bool = true,
        showBudget: Bool = true,
        showSecondaryInfo: Bool = true,
        budget: BudgetService.BudgetStatus? = nil,
        forecast: MaintenancePredictionService.MaintenanceForecast? = nil
    ) {
        self.vehicle = vehicle
        self.isWorkOrderCreated = isWorkOrderCreated
        self.showForecast = showForecast
        self.showMileage = showMileage
        self.showBudget = showBudget
        self.showSecondaryInfo = showSecondaryInfo
        self.initialBudgetStatus = budget
        self.initialForecast = forecast
    }
    
    public var body: some View {
        let settingsStore = MaintenanceSettingsStore.shared
        let status = MaintenancePredictionService.calculateStatus(for: vehicle)
        let reason = MaintenancePredictionService.getStatusReason(for: vehicle)
        
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.plateNumber)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(FMSTheme.textPrimary)
                    
                    Text("\(vehicle.manufacturer ?? "") \(vehicle.model ?? "")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(FMSTheme.textSecondary)
                }
                
                Spacer()
                
                // Status Badges (Top Right)
                HStack(spacing: 8) {
                    // Maintenance Status
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
                    
                    // Budget Status
                    if let budget = budgetStatus {
                        let isOver = budget.currentSpend > budget.budgetLimit
                        let nearLimit = budget.isAlertThresholdReached
                        
                        if isOver || nearLimit {
                            HStack(spacing: 4) {
                                Image(systemName: isOver ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                                    .font(.system(size: 8))
                                Text(isOver ? "OVER BUDGET" : "NEAR LIMIT")
                                    .font(.system(size: 10, weight: .black))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isOver ? FMSTheme.alertRed.opacity(0.12) : FMSTheme.alertOrange.opacity(0.12))
                            .foregroundColor(isOver ? FMSTheme.alertRed : FMSTheme.alertOrange)
                            .cornerRadius(12)
                        }
                    }
                }
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
                
                if showMileage {
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
                
                // Budget Progress
                if showBudget, let budget = budgetStatus {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("MONTHLY BUDGET")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(FMSTheme.textTertiary)
                                .kerning(0.5)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(Int(budget.currentSpend)) / \(Int(budget.budgetLimit)) $")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(FMSTheme.textSecondary)
                                
                                if budget.currentSpend > budget.budgetLimit {
                                    Text("OVER BUDGET: +$\(Int(budget.currentSpend - budget.budgetLimit))")
                                        .font(.system(size: 9, weight: .heavy))
                                        .foregroundColor(FMSTheme.alertRed)
                                }
                            }
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(FMSTheme.cardBackground.opacity(0.8)).frame(height: 6)
                                Capsule()
                                    .fill(budget.isAlertThresholdReached ? FMSTheme.alertRed : FMSTheme.amber)
                                    .frame(width: geo.size.width * CGFloat(min(budget.consumptionPercentage / 100.0, 1.0)), height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                    .padding(.top, 4)
                }
                
                // Maintenance Forecast
                if showForecast, let forecast = forecast, let date = forecast.projectedDate {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("SERVICE FORECAST")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(FMSTheme.textTertiary)
                                .kerning(0.5)
                            Spacer()
                            if forecast.isHighUsage {
                                Text("HIGH USAGE")
                                    .font(.system(size: 9, weight: .heavy))
                                    .foregroundColor(FMSTheme.alertRed)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(FMSTheme.alertRed.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 12))
                                .foregroundColor(FMSTheme.amber)
                            Text("Expected: \(date.formatted(date: .abbreviated, time: .omitted))")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(FMSTheme.textPrimary)
                            
                            let days = forecast.daysRemaining ?? 0
                            if days < 0 {
                                Text("(\(abs(days)) days overdue)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(FMSTheme.alertRed)
                            } else if days == 0 && status == .due {
                                Text("(ASAP)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(FMSTheme.alertRed)
                            } else {
                                Text("(\(days) days away)")
                                    .font(.system(size: 11))
                                    .foregroundColor(FMSTheme.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(FMSTheme.cardBackground.opacity(0.5))
                        .cornerRadius(8)
                    }
                    .padding(.top, 4)
                }
            }
            
            if showSecondaryInfo {
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
        }
        .padding(20)
        .background(FMSTheme.cardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isWorkOrderCreated ? FMSTheme.amber.opacity(0.5) : FMSTheme.borderLight.opacity(0.5), lineWidth: 1)
        )
        .task(id: vehicle.id) {
            // Priority 1: Injected data
            if budgetStatus == nil { budgetStatus = initialBudgetStatus }
            if showForecast && forecast == nil { forecast = initialForecast }
            
            // Priority 2: Fetch only if still nil
            if showBudget && budgetStatus == nil {
                budgetStatus = await BudgetService.shared.getBudgetStatus(for: vehicle)
            }
            if showForecast && forecast == nil {
                forecast = await MaintenancePredictionService.calculateForecast(for: vehicle)
            }
        }
    }
    
    private func statusColor(_ status: MaintenanceStatus) -> Color {
        switch status {
        case .ok:       return FMSTheme.alertGreen
        case .upcoming: return FMSTheme.alertOrange
        case .due:      return FMSTheme.alertRed
        }
    }
    
    private func calculateProgress(_ vehicle: Vehicle, settingsStore: MaintenanceSettingsStore) -> Double {
        let intervalKm = vehicle.effectiveServiceIntervalKm
        guard intervalKm > 0 else { return 0.0 }
        
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

