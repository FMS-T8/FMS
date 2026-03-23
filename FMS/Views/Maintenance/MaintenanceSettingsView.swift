import SwiftUI
import Supabase

struct MaintenanceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BannerManager.self) private var bannerManager
    @State private var fleetViewModel = FleetViewModel()
    @State private var settingsStore = MaintenanceSettingsStore.shared
    
    @State private var editingVehicle: Vehicle? = nil
    @State private var isShowingVehiclePicker = false
    @State private var saveTask: Task<Void, Never>? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                FMSTheme.backgroundPrimary.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        globalSettingsSection
                        perVehicleSettingsSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Maintenance Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.headline)
                        .foregroundColor(FMSTheme.amber)
                }
            }
            .task {
                try? await fleetViewModel.fetchVehicles()
            }
            .onChange(of: settingsStore.globalIntervalKm) { 
                saveTask?.cancel()
                saveTask = Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    guard !Task.isCancelled else { return }
                    try? await settingsStore.save()
                }
            }
        }
    }
    
    private var globalSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Global Default Rules")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(FMSTheme.textPrimary)
            
            VStack(spacing: 16) {
                settingsRow(title: "Service Interval (KM)", icon: "speedometer", text: Bindable(settingsStore).globalIntervalKm)
            }
            .padding(16)
            .background(FMSTheme.cardBackground)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMSTheme.borderLight, lineWidth: 1))
        }
    }
    
    private var perVehicleSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Per-Vehicle Overrides")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(FMSTheme.textPrimary)
                Spacer()
                Button {
                    isShowingVehiclePicker = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(FMSTheme.amber)
                        .font(.title3)
                }
            }

            if vehiclesWithOverrides.isEmpty {
                Text("No overrides configured.")
                    .font(.system(size: 14))
                    .foregroundColor(FMSTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(vehiclesWithOverrides) { vehicle in
                    VehicleOverrideCard(vehicle: vehicle, fleetViewModel: fleetViewModel) {
                        try? await fleetViewModel.fetchVehicles()
                    }
                    .onTapGesture {
                        editingVehicle = vehicle
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingVehiclePicker) {
            VehiclePickerView(vehicles: fleetViewModel.vehicles) { vehicle in
                editingVehicle = vehicle
            }
        }
        .sheet(item: $editingVehicle) { vehicle in
            VehicleMaintenanceEditView(vehicle: vehicle) {
                try? await fleetViewModel.fetchVehicles()
            }
        }
    }
    
    private func settingsRow(title: String, icon: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(FMSTheme.amber)
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(FMSTheme.textPrimary)
            
            Spacer()
            
            TextField("Value", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(FMSTheme.amber)
                .frame(width: 80)
        }
    }
    
    private var vehiclesWithOverrides: [Vehicle] {
        fleetViewModel.vehicles.filter { $0.id != MaintenanceSettingsStore.systemVehicleID && $0.serviceIntervalKm != nil }
    }
    
    // loadGlobalDefaults and saveGlobalDefaults moved to MaintenanceSettingsStore
}

struct VehicleOverrideCard: View {
    let vehicle: Vehicle
    var fleetViewModel: FleetViewModel
    var onUpdate: () async -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(vehicle.plateNumber)
                        .font(.system(size: 16, weight: .bold))
                    Text("\(vehicle.manufacturer ?? "") \(vehicle.model ?? "")")
                        .font(.system(size: 12))
                        .foregroundColor(FMSTheme.textSecondary)
                }
                Spacer()
                Button(role: .destructive) {
                    clearOverride()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .padding(8)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            
            Divider()
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Km Interval")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(FMSTheme.textTertiary)
                    Text("\(Int(vehicle.serviceIntervalKm ?? 0)) km")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .padding(14)
        .background(FMSTheme.cardBackground)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMSTheme.borderLight, lineWidth: 1))
    }
    
    private func clearOverride() {
        Task {
            do {
                // Explicitly send null to database (Encodable might strip nil values otherwise)
                struct NullUpdate: Encodable {
                    func encode(to encoder: Encoder) throws {
                        var container = encoder.container(keyedBy: CodingKeys.self)
                        try container.encodeNil(forKey: .service_interval_km)
                    }
                    enum CodingKeys: String, CodingKey {
                        case service_interval_km
                    }
                }
                
                try await SupabaseService.shared.client
                    .from("vehicles")
                    .update(NullUpdate())
                    .eq("id", value: vehicle.id)
                    .execute()
                
                await onUpdate()
            } catch {
                print("Failed to delete override: \(error)")
            }
        }
    }
}

struct VehiclePickerView: View {
    let vehicles: [Vehicle]
    let onSelect: (Vehicle) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""
    
    var filteredVehicles: [Vehicle] {
        let realVehicles = vehicles.filter { $0.id != MaintenanceSettingsStore.systemVehicleID }
        if searchText.isEmpty { return realVehicles }
        return realVehicles.filter { 
            $0.plateNumber.localizedCaseInsensitiveContains(searchText) ||
            ($0.manufacturer ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.model ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color(red: 18/255, green: 18/255, blue: 18/255) : FMSTheme.backgroundPrimary).ignoresSafeArea()
                
                List(filteredVehicles) { vehicle in
                    Button {
                        onSelect(vehicle)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(vehicle.plateNumber)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                                Text("\(vehicle.manufacturer ?? "") \(vehicle.model ?? "")")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(FMSTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(FMSTheme.amber)
                        }
                        .padding(16)
                        .background(FMSTheme.cardBackground)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(FMSTheme.borderLight.opacity(colorScheme == .dark ? 0.15 : 1), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Select Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search plate or model...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(FMSTheme.amber)
                }
            }
        }
    }
}
