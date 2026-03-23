import SwiftUI

public struct FleetReportView: View {
    @Environment(BannerManager.self) private var bannerManager
    @State private var viewModel = FleetReportViewModel()
    
    // Pickers states
    @State private var showDatePicker = false
    @State private var showVehiclePicker = false
    @State private var showDriverPicker = false
    
    // Temporary draft dates for the custom date range sheet
    @State private var draftStartDate: Date = Date()
    @State private var draftEndDate: Date = Date()
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 1. Filter Bar
                filterBar
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                if viewModel.isLoading {
                    ProgressView("Crunching fleet data...")
                        .padding(.top, 50)
                } else {
                    // 2. Metrics Grid
                    metricsGrid
                        .padding(.horizontal)
                    
                    // 3. Email Subscription Toggle
                    emailSubscriptionSection
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                }
            }
        }
        .background(FMSTheme.backgroundPrimary)
        .navigationTitle("Fleet Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.selectedPreset != .thisWeek || viewModel.selectedVehicleId != nil || viewModel.selectedDriverId != nil {
                    Button("Clear Filters") {
                        viewModel.selectedPreset = .thisWeek
                        viewModel.selectedVehicleId = nil
                        viewModel.selectedDriverId = nil
                        Task { await loadData() }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FMSTheme.amber)
                }
            }
        }
        .task {
            // Initial load
            await viewModel.loadFilters()
            await loadData()
            await viewModel.fetchSubscriptionStatus()
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                Form {
                    DatePicker("Start Date", selection: $draftStartDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $draftEndDate, in: draftStartDate..., displayedComponents: .date)
                }
                .navigationTitle("Custom Date Range")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    draftStartDate = viewModel.startDate
                    draftEndDate = viewModel.endDate
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            showDatePicker = false
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Apply") {
                            viewModel.startDate = draftStartDate
                            viewModel.endDate = draftEndDate
                            showDatePicker = false
                            viewModel.selectedPreset = .custom
                            Task { await loadData() }
                        }
                        .fontWeight(.bold)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
    
    private func loadData() async {
        await viewModel.fetchReportData()
        if let error = viewModel.errorMessage {
            bannerManager.show(type: .error, message: error)
            viewModel.errorMessage = nil // clear it after showing banner
        }
    }
    
    // MARK: - Filters
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Date Filter
                Menu {
                    ForEach(FleetReportViewModel.DatePreset.allCases) { preset in
                        Button(preset.rawValue) {
                            if preset == .custom {
                                showDatePicker = true
                            } else {
                                viewModel.selectedPreset = preset
                                Task { await loadData() }
                            }
                        }
                    }
                } label: {
                    filterChip(
                        icon: "calendar",
                        text: viewModel.selectedPreset == .custom ? "Custom" : viewModel.selectedPreset.rawValue,
                        isActive: true
                    )
                }
                
                // Vehicle Filter
                Menu {
                    Button("All Vehicles") {
                        viewModel.selectedVehicleId = nil
                        Task { await loadData() }
                    }
                    Divider()
                    ForEach(viewModel.availableVehicles) { vehicle in
                        Button(vehicle.plateNumber) {
                            viewModel.selectedVehicleId = vehicle.id
                            Task { await loadData() }
                        }
                    }
                } label: {
                    let text = viewModel.availableVehicles.first(where: { $0.id == viewModel.selectedVehicleId })?.plateNumber ?? "All Vehicles"
                    filterChip(icon: "truck.box", text: text, isActive: viewModel.selectedVehicleId != nil)
                }
                
                // Driver Filter
                Menu {
                    Button("All Drivers") {
                        viewModel.selectedDriverId = nil
                        Task { await loadData() }
                    }
                    Divider()
                    ForEach(viewModel.availableDrivers) { driver in
                        Button(driver.name) {
                            viewModel.selectedDriverId = driver.id
                            Task { await loadData() }
                        }
                    }
                } label: {
                    let text = viewModel.availableDrivers.first(where: { $0.id == viewModel.selectedDriverId })?.name ?? "All Drivers"
                    filterChip(icon: "person.2", text: text, isActive: viewModel.selectedDriverId != nil)
                }
            }
        }
    }
    
    private func filterChip(icon: String, text: String, isActive: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
        }
        .font(.system(size: 14, weight: .semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isActive ? FMSTheme.amber.opacity(0.15) : FMSTheme.cardBackground)
        .foregroundStyle(isActive ? FMSTheme.amberDark : FMSTheme.textSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isActive ? FMSTheme.amber.opacity(0.3) : FMSTheme.borderLight, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Metrics Grid
    
    private var metricsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
        
        return VStack(spacing: 24) {
            // Trips & Distances
            VStack(alignment: .leading, spacing: 12) {
                Text("Operational")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(FMSTheme.textPrimary)
                
                LazyVGrid(columns: columns, spacing: 16) {
                    ReportMetricCard(
                        icon: "map.fill", title: "Total Trips",
                        value: "\(viewModel.totalTrips)",
                        subtitle: "\(viewModel.completedTrips) completed"
                    )
                    ReportMetricCard(
                        icon: "point.topleft.down.curvedto.point.bottomright.up", title: "Distance",
                        value: "\(Int(viewModel.totalDistanceKm)) km"
                    )
                }
            }
            
            // Fuel
            VStack(alignment: .leading, spacing: 12) {
                Text("Fuel & Efficiency")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(FMSTheme.textPrimary)
                
                LazyVGrid(columns: columns, spacing: 16) {
                    ReportMetricCard(
                        icon: "fuelpump.fill", title: "Fuel Used",
                        value: String(format: "%.1f L", viewModel.totalFuelLiters)
                    )
                    ReportMetricCard(
                        icon: "indianrupeesign", title: "Fuel Cost",
                        value: String(format: "₹%.0f", viewModel.totalFuelCost),
                        subtitle: String(format: "Avg %.1f km/L", viewModel.avgFuelEfficiency)
                    )
                }
            }
            
            // Safety & Maintenance
            VStack(alignment: .leading, spacing: 12) {
                Text("Safety & Maintenance")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(FMSTheme.textPrimary)
                
                LazyVGrid(columns: columns, spacing: 16) {
                    ReportMetricCard(
                        icon: "exclamationmark.triangle.fill", title: "Incidents",
                        value: "\(viewModel.incidentCount)",
                        subtitle: "\(viewModel.safetyEventCount) sensor events"
                    )
                    ReportMetricCard(
                        icon: "wrench.and.screwdriver.fill", title: "Work Orders",
                        value: "\(viewModel.activeMaintenanceCount)",
                        subtitle: "\(viewModel.completedMaintenanceCount) resolved"
                    )
                }
            }
        }
    }
    
    // MARK: - Email Subscription
    
    private var emailSubscriptionSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(FMSTheme.amber.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(FMSTheme.amber)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Automated Reports")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(FMSTheme.textPrimary)
                    
                    Text("Receive this summary via email every Monday morning.")
                        .font(.subheadline)
                        .foregroundStyle(FMSTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { viewModel.isSubscribedToEmail },
                    set: { newValue in
                        // Instantly update the UI natively
                        viewModel.isSubscribedToEmail = newValue
                        // Trigger the background sync
                        Task { await viewModel.syncEmailSubscription(newValue) }
                    }
                ))
                .labelsHidden()
                .tint(FMSTheme.amber)
            }
            .padding(16)
        }
        .background(FMSTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(FMSTheme.borderLight, lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        FleetReportView()
    }
    .environment(BannerManager())
}
