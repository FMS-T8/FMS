import SwiftUI

public struct MaintenanceManagerView: View {
    @State private var fleetViewModel = FleetViewModel()
    @State private var showingSettings = false
    @State private var selectedVehicle: Vehicle? = nil
    @State private var searchText = ""
    @State private var selectedStatusFilter: MaintenanceStatus? = nil
    @State private var woStore = WorkOrderStore()
    @State private var showingHistory = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                FMSTheme.backgroundPrimary.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            HStack {
                                Text("Maintenance")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(FMSTheme.textPrimary)
                                
                                Spacer()
                                
                                HStack(spacing: 12) {
                                    Button {
                                        showingHistory = true
                                    } label: {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(FMSTheme.amber)
                                    }
                                    
                                    Button {
                                        showingSettings = true
                                    } label: {
                                        Image(systemName: "gearshape.fill")
                                            .font(.system(size: 18, weight: .semibold))
                                            .padding(8)
                                            .background(FMSTheme.amber.opacity(0.12))
                                            .clipShape(Circle())
                                            .foregroundStyle(FMSTheme.amber)
                                    }
                                }
                            }
                            
                            statusSummarySection
                            statusFilterSection
                            vehicleListSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search vehicle...")
            .toolbar(.hidden, for: .navigationBar)
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
            }
        }
    }
    
    private var statusFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                filterChip(title: "All", count: realVehicles.count, status: nil)
                filterChip(title: "Due", count: dueCount, status: .due)
                filterChip(title: "Upcoming", count: upcomingCount, status: .upcoming)
                filterChip(title: "OK", count: okCount, status: .ok)
            }
        }
    }
    
    private func filterChip(title: String, count: Int, status: MaintenanceStatus?) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedStatusFilter = status
            }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                
                Text("\(count)")
                    .font(.system(size: 12, weight: .black))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(selectedStatusFilter == status ? Color.black.opacity(0.1) : Color.black.opacity(0.1))
                    .cornerRadius(6)
            }
            .foregroundColor(selectedStatusFilter == status ? .black : FMSTheme.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(selectedStatusFilter == status ? FMSTheme.amber : FMSTheme.cardBackground.opacity(0.8))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedStatusFilter == status ? Color.clear : FMSTheme.borderLight, lineWidth: 1)
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
                        VehicleServiceCard(vehicle: vehicle, isWorkOrderCreated: true)
                    } else {
                        Button {
                            selectedVehicle = vehicle
                        } label: {
                            VehicleServiceCard(vehicle: vehicle, isWorkOrderCreated: false)
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
