import SwiftUI
import Supabase

public struct FleetManagementView: View {
    @Environment(BannerManager.self) private var bannerManager
    @State private var viewModel = FleetViewModel()
    @State private var showingAddVehicle = false
    @State private var selectedVehicle: Vehicle? = nil
    @State private var trackingTrip: Trip? = nil
    @State private var isFetchingTrip = false
    @State private var showingBulkImport = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                FMSTheme.backgroundPrimary.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                Text("Fleet Management")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(FMSTheme.textPrimary)
                                
                                Spacer()
                                
                                HStack(spacing: 12) {
                                    Button {
                                        showingBulkImport = true
                                    } label: {
                                        Image(systemName: "doc.badge.plus")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(FMSTheme.textPrimary)
                                    }
                                    
                                    Button {
                                        showingAddVehicle = true
                                    } label: {
                                        Image(systemName: "plus")
                                            .font(.system(size: 20, weight: .bold))
                                            .padding(8)
                                            .background(FMSTheme.amber.opacity(0.12))
                                            .clipShape(Circle())
                                            .foregroundStyle(FMSTheme.amber)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            summaryCardSection
                            
                            VStack(spacing: 16) {
                                filterSection
                            }
                            
                            // Vehicle List
                            vehicleListSection
                        }
                        .padding(.top, 16)
                    }
                }
            }
            .task {
                do {
                    try await viewModel.fetchVehicles()
                } catch {
                }
            }
            .onChange(of: viewModel.errorMessage) { _, newValue in
                guard let message = newValue else { return }
                bannerManager.show(type: .error, message: message)
                viewModel.errorMessage = nil
            }
            .sheet(isPresented: $showingAddVehicle) {
                AddVehicleView { newVehicle in
                    try await viewModel.addVehicle(newVehicle)
                }
            }
            // MARK: - Bulk Import Sheet
            .sheet(isPresented: $showingBulkImport) {
                VehicleBulkImportView {
                    // Refresh the list after successful import
                    Task {
                        do {
                            try await viewModel.fetchVehicles()
                        } catch {
                            bannerManager.show(type: .error, message: "Failed to refresh vehicles after import.")
                        }
                    }
                }
            }
            .navigationDestination(item: $selectedVehicle) { vehicle in
                VehicleDetailView(
                    vehicle: vehicle,
                    onUpdate: { updatedVehicle in
                        try await viewModel.updateVehicle(updatedVehicle)
                    },
                    onDelete: { vehicleId in
                        try await viewModel.deleteVehicle(id: vehicleId)
                    }
                )
            }
            .navigationDestination(item: $trackingTrip) { trip in
                TripReplayView(trip: trip)
            }
            .searchable(text: $viewModel.searchText, prompt: "Search plate, make, or model")
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.statusOptions, id: \.self) { status in
                    let count = status == "All" ? viewModel.vehicles.count : countForStatus(status)
                    FilterPill(
                        title: status == "All" ? "All" : statusLabel(status),
                        count: count,
                        statusKey: status,
                        isSelected: viewModel.selectedStatus == status,
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.selectedStatus = status
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    private var vehicleListSection: some View {
        if viewModel.isLoading && viewModel.vehicles.isEmpty {
            VStack {
                Spacer(minLength: 100)
                ProgressView("Loading vehicles...")
                    .progressViewStyle(CircularProgressViewStyle(tint: FMSTheme.textSecondary))
                    .foregroundColor(FMSTheme.textSecondary)
                Spacer()
            }
        } else if let loadError = viewModel.loadErrorMessage, viewModel.vehicles.isEmpty {
            VStack {
                Spacer(minLength: 100)
                VStack(spacing: 8) {
                    Text("Unable to load vehicles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(FMSTheme.textPrimary)
                    Text(loadError)
                        .font(.system(size: 13))
                        .foregroundColor(FMSTheme.textTertiary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                Spacer()
            }
        } else if viewModel.vehicles.isEmpty {
            VStack {
                Spacer(minLength: 100)
                Text("No vehicles found.")
                    .font(.system(size: 16))
                    .foregroundColor(FMSTheme.textTertiary)
                Spacer()
            }
        } else if viewModel.filteredVehicles.isEmpty {
            VStack {
                Spacer(minLength: 100)
                Text("No results match your filters.")
                    .font(.system(size: 16))
                    .foregroundColor(FMSTheme.textTertiary)
                Spacer()
            }
        } else {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredVehicles) { vehicle in
                    VehicleListCard(
                        vehicle: vehicle,
                        onTrack: { v in
                            Task { await fetchActiveTrip(for: v) }
                        },
                        derivedStatus: viewModel.derivedStatus(for: vehicle)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 14))
                    .onTapGesture {
                        selectedVehicle = vehicle
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 120)
        }
    }
    
    private var summaryCardSection: some View {
        FMSMaintenanceSummaryCard(
            title: "FLEET STATUS",
            mainCount: viewModel.activeCount,
            mainLabel: "Active",
            subtitle: "Tracking \(viewModel.vehicles.count) vehicles across all regions.",
            showWarning: false,
            subItems: [
                .init(icon: "wrench.and.screwdriver.fill", count: viewModel.maintenanceCount, label: "Under Maintenance"),
                .init(icon: "truck.box.fill", count: viewModel.inactiveCount, label: "At Yard")
            ]
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Summary Helpers
private extension FleetManagementView {
    
    @MainActor
    func fetchActiveTrip(for vehicle: Vehicle) async {
        guard !isFetchingTrip else { return }
        isFetchingTrip = true
        defer { isFetchingTrip = false }
        do {
            let activeStatuses = ["active", "in_progress", "in_transit"]
            let trips: [Trip] = try await SupabaseService.shared.client
                .from("trips")
                .select()
                .eq("vehicle_id", value: vehicle.id)
                .in("status", values: activeStatuses)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            if let trip = trips.first {
                trackingTrip = trip
            } else {
                trackingTrip = nil
                bannerManager.show(type: .warning, message: "No active trip found for \(vehicle.plateNumber).")
            }
        } catch {
            print("[FleetManagementView] Failed to fetch active trip: \(error)")
            bannerManager.show(type: .error, message: "Failed to fetch active trip for \(vehicle.plateNumber).")
        }
    }
    
    func countForStatus(_ status: String) -> Int {
        let normalizedStatus = normalizeStatus(status)
        return vehiclesMatchingSearch()
            .filter { normalizeStatus(viewModel.derivedStatus(for: $0)) == normalizedStatus }
            .count
    }
    
    func statusLabel(_ status: String) -> String {
        switch status.lowercased() {
        case "active": return "On Trip"
        case "maintenance": return "Maintenance"
        case "inactive": return "In Yard"
        default: return status
        }
    }
    
    func normalizeStatus(_ status: String) -> String {
        VehicleStatus.normalize(status)
    }

    func vehiclesMatchingSearch() -> [Vehicle] {
        if viewModel.searchText.isEmpty {
            return viewModel.vehicles
        }
        let searchLower = viewModel.searchText.lowercased()
        return viewModel.vehicles.filter { vehicle in
            let plate = vehicle.plateNumber.lowercased()
            let make = (vehicle.manufacturer ?? "").lowercased()
            let model = (vehicle.model ?? "").lowercased()
            return plate.contains(searchLower) || make.contains(searchLower) || model.contains(searchLower)
        }
    }
}

// MARK: - Subviews
struct FilterPill: View {
    let title: String
    let count: Int
    let statusKey: String
    let isSelected: Bool
    let action: () -> Void
    
    // Status color mapping for filters
    private var statusColor: Color {
        let normalized = statusKey.lowercased()
        switch normalized {
        case "active": return FMSTheme.alertGreen
        case "maintenance": return FMSTheme.alertAmber
        case "inactive": return FMSTheme.textTertiary
        case "all": return FMSTheme.amber
        default: return FMSTheme.textTertiary
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if statusKey.lowercased() != "all" || isSelected {
                    Circle()
                        .fill(isSelected && statusKey.lowercased() == "all" ? FMSTheme.obsidian : statusColor)
                        .frame(width: 8, height: 8)
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(FMSTheme.textPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(FMSTheme.backgroundPrimary)
                    .cornerRadius(20)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .foregroundColor(isSelected ? FMSTheme.obsidian : FMSTheme.textPrimary)
            .background(
                Group {
                    if isSelected {
                        FMSTheme.amber
                    } else {
                        FMSTheme.cardBackground.opacity(0.5)
                            .fmsGlassEffect(cornerRadius: 20)
                    }
                }
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? FMSTheme.amber : FMSTheme.textPrimary.opacity(0.1), lineWidth: 1) // Adaptive glass edge highlight
            )
            .shadow(color: isSelected ? FMSTheme.amber.opacity(0.2) : FMSTheme.shadowSmall, radius: 4, x: 0, y: 2)
        }
    }
}

#Preview {
    FleetManagementView()
        .environment(BannerManager())
}
