import SwiftUI

public struct MaintenanceManagerView: View {
    @Bindable private var settingsStore = MaintenanceSettingsStore.shared
    @State private var fleetViewModel = FleetViewModel()
    @State private var showingSettings = false
    @State private var selectedVehicle: Vehicle? = nil
    @State private var searchText = ""
    @State private var selectedStatusFilter: MaintenanceStatus? = nil
    @State private var woStore = WorkOrderStore()
    @State private var showingHistory = false
    @State private var budgetStatuses: [String: BudgetService.BudgetStatus] = [:]
    // forecasts removed as it's now on the dashboard
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                FMSTheme.backgroundPrimary.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    headerSection
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            searchSection
                            statusSummarySection
                            statusFilterSection
                            vehicleListSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .toolbar(.hidden) // Hiding standard toolbar to use custom header row
            .sheet(isPresented: $showingSettings, onDismiss: {
                Task { try? await fleetViewModel.fetchVehicles() }
            }) {
                MaintenanceSettingsView()
            }
            .sheet(item: $selectedVehicle) { vehicle in
                RecommendationDetailView(vehicle: vehicle, store: woStore)
            }
            .sheet(isPresented: $showingHistory) {
                MaintenanceHistoryView(woStore: woStore)
            }
            .task {
                await MaintenanceSettingsStore.shared.fetchRemoteConfig()
                try? await fleetViewModel.fetchVehicles()
                await woStore.fetchWorkOrders()
                await refreshBudgetStatuses()
            }
            .onChange(of: settingsStore.globalMonthlyBudget) {
                recalculateBudgets()
            }
            .onChange(of: settingsStore.globalIntervalKm) {
                // Interval changes affect the counts in the header/chips, 
                // which are already reactive because they use computed properties.
            }
        }
    }
    
    private func recalculateBudgets() {
        let globalLimit = settingsStore.monthlyBudgetDouble
        for (vehicleID, status) in budgetStatuses {
            guard let vehicle = fleetViewModel.vehicles.first(where: { $0.id == vehicleID }) else { continue }
            let effectiveLimit = vehicle.monthlyBudget ?? globalLimit
            budgetStatuses[vehicleID] = BudgetService.BudgetStatus(
                currentSpend: status.currentSpend,
                budgetLimit: effectiveLimit
            )
        }
    }
    
    // refreshForecasts removed
    
    private func refreshBudgetStatuses() async {
        for vehicle in fleetViewModel.vehicles {
            budgetStatuses[vehicle.id] = await BudgetService.shared.getBudgetStatus(for: vehicle)
        }
    }
    
    private var headerSection: some View {
        HStack(alignment: .center) {
            Text("Maintenance")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(FMSTheme.textPrimary)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    showingHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 18))
                        .foregroundColor(FMSTheme.amber)
                        .padding(10)
                        .background(FMSTheme.cardBackground)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 4)
                }
                
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                        .foregroundColor(FMSTheme.amber)
                        .padding(10)
                        .background(FMSTheme.cardBackground)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 4)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }
    
    private var searchSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(FMSTheme.textTertiary)
                .font(.system(size: 14))
            TextField("Search vehicle...", text: $searchText)
                .font(.system(size: 14))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(FMSTheme.cardBackground.opacity(0.5))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMSTheme.borderLight.opacity(0.5), lineWidth: 1))
    }
    
    private var statusFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                filterChip(title: "All", count: realVehicles.count, status: nil)
                filterChip(title: "Due", count: dueCount, status: .due)
                filterChip(title: "Upcoming", count: upcomingCount, status: .upcoming)
                filterChip(title: "OK", count: okCount, status: .ok)
                
                // Budget filters
                let overBudgetCount = budgetStatuses.values.filter { $0.currentSpend > $0.budgetLimit }.count
                filterChip(title: "Over Budget", count: overBudgetCount, budgetFilter: .overBudget)
                
                let nearBudgetViewCount = budgetStatuses.values.filter { 
                    let percentage = $0.budgetLimit > 0 ? ($0.currentSpend / $0.budgetLimit) * 100 : 0
                    return percentage >= 80.0 && percentage <= 100.0 
                }.count
                filterChip(title: "Near Budget", count: nearBudgetViewCount, budgetFilter: .nearBudget)
            }
        }
    }
    
    private enum BudgetFilter {
        case overBudget
        case nearBudget
    }
    
    @State private var selectedBudgetFilter: BudgetFilter? = nil
    
    private func filterChip(
        title: String, 
        count: Int, 
        status: MaintenanceStatus? = nil, 
        budgetFilter: BudgetFilter? = nil
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                if let bf = budgetFilter {
                    if selectedBudgetFilter == bf {
                        selectedBudgetFilter = nil
                    } else {
                        selectedBudgetFilter = bf
                        selectedStatusFilter = nil
                    }
                } else {
                    selectedStatusFilter = status
                    selectedBudgetFilter = nil
                }
            }
        } label: {
            let isSelected = (budgetFilter != nil && selectedBudgetFilter == budgetFilter) || 
                             (budgetFilter == nil && selectedStatusFilter == status && selectedBudgetFilter == nil)
            
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                
                Text("\(count)")
                    .font(.system(size: 12, weight: .black))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .cornerRadius(6)
            }
            .foregroundColor(isSelected ? .black : FMSTheme.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? (budgetFilter != nil ? FMSTheme.alertRed : FMSTheme.amber) : FMSTheme.cardBackground.opacity(0.8))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : FMSTheme.borderLight, lineWidth: 1)
            )
        }
    }
    
    private var statusSummarySection: some View {
        FMSMaintenanceSummaryCard(
            title: "FLEET STATUS",
            mainCount: dueCount,
            mainLabel: "Due",
            subtitle: dueCount == 0 ? "All vehicles are serviced or on schedule" : "Critical service required for \(dueCount) vehicles",
            showWarning: true,
            subItems: [
                .init(icon: "clock.fill", count: upcomingCount, label: "Upcoming"),
                .init(icon: "checkmark.circle.fill", count: okCount, label: "Serviced")
            ]
        )
    }
    
    private var vehicleListSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Fleet Service Status")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(FMSTheme.textPrimary)
            
            if filteredVehicles.isEmpty {
                Text("No vehicles match your search.")
                    .font(.system(size: 14))
                    .foregroundColor(FMSTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                ForEach(filteredVehicles) { vehicle in
                    let hasActiveWO = woStore.orders.contains { 
                        $0.vehicleIdRaw == vehicle.id && $0.status != .completed && $0.isService
                    }
                    
                    if hasActiveWO {
                        VehicleServiceCard(
                            vehicle: vehicle, 
                            isWorkOrderCreated: true,
                            budget: budgetStatuses[vehicle.id]
                        )
                    } else {
                        Button {
                            selectedVehicle = vehicle
                        } label: {
                            VehicleServiceCard(
                                vehicle: vehicle, 
                                isWorkOrderCreated: false,
                                budget: budgetStatuses[vehicle.id]
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
    
    /// Real vehicles only — excludes the system settings row
    private var realVehicles: [Vehicle] {
        fleetViewModel.vehicles.filter { $0.id != MaintenanceSettingsStore.systemVehicleID }
    }
    
    private var filteredVehicles: [Vehicle] {
        var result = realVehicles
        let settingsStore = MaintenanceSettingsStore.shared
        
        if let statusFilter = selectedStatusFilter {
            result = result.filter { 
                MaintenancePredictionService.calculateStatus(
                    for: $0, 
                    defaultKm: settingsStore.intervalKmDouble
                ) == statusFilter 
            }
        }
        
        if let budgetFilter = selectedBudgetFilter {
            result = result.filter { vehicle in
                guard let stat = budgetStatuses[vehicle.id] else { return false }
                if budgetFilter == .overBudget {
                    return stat.currentSpend > stat.budgetLimit
                } else {
                    return stat.isAlertThresholdReached && stat.currentSpend <= stat.budgetLimit
                }
            }
        }
        
        if !searchText.isEmpty {
            result = result.filter {
                $0.plateNumber.localizedCaseInsensitiveContains(searchText) ||
                ($0.manufacturer ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.model ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    private var dueCount: Int {
        let settingsStore = MaintenanceSettingsStore.shared
        return realVehicles.filter { 
            MaintenancePredictionService.calculateStatus(
                for: $0, 
                defaultKm: settingsStore.intervalKmDouble
            ) == .due 
        }.count
    }
    
    private var upcomingCount: Int {
        let settingsStore = MaintenanceSettingsStore.shared
        return realVehicles.filter { 
            MaintenancePredictionService.calculateStatus(
                for: $0, 
                defaultKm: settingsStore.intervalKmDouble
            ) == .upcoming 
        }.count
    }
    
    private var okCount: Int {
        let settingsStore = MaintenanceSettingsStore.shared
        return realVehicles.filter { 
            MaintenancePredictionService.calculateStatus(
                for: $0, 
                defaultKm: settingsStore.intervalKmDouble
            ) == .ok 
        }.count
    }
}
