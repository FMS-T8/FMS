import SwiftUI

public struct MaintenanceForecastView: View {
    @State private var fleetViewModel = FleetViewModel()
    @State private var forecasts: [String: MaintenancePredictionService.MaintenanceForecast] = [:]
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var showingProfile = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                FMSTheme.backgroundPrimary.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    FMSTitleRow(title: "Forecast")
                    Divider().opacity(0.35)
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            forecastSummarySection
                            
                            searchSection
                            
                            highUsageSection
                            
                            upcomingServicesSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 32)
                    }
                }
            }
            .toolbar(.hidden)
            .task {
                await refreshData()
            }
            .sheet(isPresented: $showingProfile) {
                ProfileTabView()
            }
        }
    }
    
    private func refreshData() async {
        isLoading = true
        try? await fleetViewModel.fetchVehicles()
        
        let vehicles = fleetViewModel.vehicles.filter { $0.id != MaintenanceSettingsStore.systemVehicleID }
        for vehicle in vehicles {
            forecasts[vehicle.id] = await MaintenancePredictionService.calculateForecast(
                for: vehicle,
                defaultKm: MaintenanceSettingsStore.shared.intervalKmDouble
            )
        }
        isLoading = false
    }
    
    private var loadingPlaceholder: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(FMSTheme.amber)
            Text("Analyzing fleet usage patterns...")
                .font(.system(size: 14))
                .foregroundColor(FMSTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var forecastSummarySection: some View {
        let highUsageCount = forecasts.values.filter { $0.isHighUsage }.count
        let dueCount = fleetViewModel.vehicles.filter { $0.id != MaintenanceSettingsStore.systemVehicleID }.filter { 
            MaintenancePredictionService.calculateStatus(
                for: $0, 
                defaultKm: MaintenanceSettingsStore.shared.intervalKmDouble
            ) == .due 
        }.count
        
        var subItems: [FMSMaintenanceSummaryCard.SummarySubItemData] = []
        subItems.append(.init(icon: "gauge.with.dots.needle.50percent", count: highUsageCount, label: "High Usage"))
        
        let upcomingCount = fleetViewModel.vehicles.filter { $0.id != MaintenanceSettingsStore.systemVehicleID }.filter { 
            MaintenancePredictionService.calculateStatus(
                for: $0, 
                defaultKm: MaintenanceSettingsStore.shared.intervalKmDouble
            ) == .upcoming 
        }.count
        subItems.append(.init(icon: "clock.fill", count: upcomingCount, label: "Upcoming"))

        return FMSMaintenanceSummaryCard(
            title: "PROACTIVE PLANNING",
            mainCount: dueCount,
            mainLabel: "Due",
            subtitle: dueCount == 0 ? "Fleet is currently up to date" : "Critical attention required for \(dueCount) vehicles",
            showWarning: dueCount > 0,
            subItems: subItems
        )
    }
    
    private var searchSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(FMSTheme.textTertiary)
                .font(.system(size: 14))
            TextField("Search fleet...", text: $searchText)
                .font(.system(size: 14))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(FMSTheme.cardBackground.opacity(0.5))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMSTheme.borderLight.opacity(0.5), lineWidth: 1))
    }
    
    private var highUsageSection: some View {
        let highUsageVehicles = fleetViewModel.vehicles.filter { vehicle in
            guard let fc = forecasts[vehicle.id] else { return false }
            return fc.isHighUsage && matchesSearch(vehicle)
        }
        
        return VStack(alignment: .leading, spacing: 14) {
            if !highUsageVehicles.isEmpty {
                HStack {
                    Text("CRITICAL USAGE")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(FMSTheme.alertRed)
                    Spacer()
                    Text("\(highUsageVehicles.count) Vehicles")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(FMSTheme.textTertiary)
                }
                
                ForEach(highUsageVehicles) { vehicle in
                    VehicleServiceCard(
                        vehicle: vehicle,
                        showForecast: true,
                        showMileage: false,
                        showBudget: false,
                        showSecondaryInfo: false,
                        forecast: forecasts[vehicle.id]
                    )
                }
            }
        }
    }
    
    private var upcomingServicesSection: some View {
        let upcoming = fleetViewModel.vehicles.filter { vehicle in
            guard let fc = forecasts[vehicle.id] else { return false }
            return !fc.isHighUsage && fc.projectedDate != nil && matchesSearch(vehicle)
        }.sorted { v1, v2 in
            let d1 = forecasts[v1.id]?.projectedDate ?? Date.distantFuture
            let d2 = forecasts[v2.id]?.projectedDate ?? Date.distantFuture
            return d1 < d2
        }
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("UPCOMING SERVICES")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(FMSTheme.textTertiary)
                Spacer()
            }
            
            if upcoming.isEmpty && !isLoading {
                Text("No upcoming projections.")
                    .font(.system(size: 14))
                    .foregroundColor(FMSTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(upcoming) { vehicle in
                    VehicleServiceCard(
                        vehicle: vehicle,
                        showForecast: true,
                        showMileage: false,
                        showBudget: false,
                        showSecondaryInfo: false,
                        forecast: forecasts[vehicle.id]
                    )
                }
            }
        }
    }
    
    private func matchesSearch(_ vehicle: Vehicle) -> Bool {
        if searchText.isEmpty { return true }
        let term = searchText.lowercased()
        return vehicle.plateNumber.lowercased().contains(term) ||
               (vehicle.manufacturer ?? "").lowercased().contains(term) ||
               (vehicle.model ?? "").lowercased().contains(term)
    }
}
