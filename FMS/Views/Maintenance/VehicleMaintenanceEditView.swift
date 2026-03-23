import SwiftUI

struct VehicleMaintenanceEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BannerManager.self) private var bannerManager
    
    let vehicle: Vehicle
    var onUpdate: () async -> Void
    
    @State private var fleetViewModel = FleetViewModel()
    
    // Form State
    @State private var odometer: String = ""
    @State private var lastServiceDate: Date = Date()
    @State private var lastServiceOdometer: String = ""
    @State private var notes: String = ""
    @State private var serviceIntervalKm: String = ""
    
    @State private var isSaving = false
    
    init(vehicle: Vehicle, onUpdate: @escaping () async -> Void) {
        self.vehicle = vehicle
        self.onUpdate = onUpdate
        
        _odometer = State(initialValue: String(format: "%.0f", vehicle.odometer ?? 0))
        _lastServiceDate = State(initialValue: vehicle.lastServiceDate ?? Date())
        _lastServiceOdometer = State(initialValue: String(format: "%.0f", vehicle.lastServiceOdometer ?? 0))
        _notes = State(initialValue: vehicle.notes ?? "")
        _serviceIntervalKm = State(initialValue: String(format: "%.0f", vehicle.serviceIntervalKm ?? MaintenancePredictionService.defaultIntervalKm))
    }
    
    @State private var pendingSave: Task<Void, Never>? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                FMSTheme.backgroundPrimary.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        vehicleInfoSection
                        maintenanceDataSection
                        intervalSettingsSection
                        notesSection
                    }
                    .padding(20)
                }
                
                if isSaving {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressView()
                        .padding(20)
                        .background(FMSTheme.cardBackground)
                        .cornerRadius(12)
                }
            }
            .navigationTitle("Edit Vehicle Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.headline)
                        .foregroundColor(FMSTheme.amber)
                }
            }
            .onChange(of: odometer) { scheduleAutoSave() }
            .onChange(of: lastServiceDate) { scheduleAutoSave() }
            .onChange(of: lastServiceOdometer) { scheduleAutoSave() }
            .onChange(of: notes) { scheduleAutoSave() }
            .onChange(of: serviceIntervalKm) { scheduleAutoSave() }
        }
    }
    
    private var vehicleInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VEHICLE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(FMSTheme.textTertiary)
            
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(FMSTheme.amber.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: "truck.box.fill")
                        .foregroundColor(FMSTheme.amber)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(vehicle.plateNumber)
                        .font(.system(size: 16, weight: .bold))
                    Text("\(vehicle.manufacturer ?? "") \(vehicle.model ?? "")")
                        .font(.system(size: 13))
                        .foregroundColor(FMSTheme.textSecondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FMSTheme.cardBackground)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMSTheme.borderLight, lineWidth: 1))
        }
    }
    
    private var maintenanceDataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MAINTENANCE METRICS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(FMSTheme.textTertiary)
            
            VStack(spacing: 0) {
                InputField(title: "Current Odometer (km)", text: $odometer, icon: "speedometer")
                Divider().padding(.leading, 44)
                
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .foregroundColor(FMSTheme.amber)
                        .frame(width: 24)
                    DatePicker("Last Service Date", selection: $lastServiceDate, displayedComponents: .date)
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(14)
                
                Divider().padding(.leading, 44)
                InputField(title: "Last Service Odometer (km)", text: $lastServiceOdometer, icon: "clock.fill")
            }
            .background(FMSTheme.cardBackground)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMSTheme.borderLight, lineWidth: 1))
        }
    }
    
    private var intervalSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SERVICE INTERVALS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(FMSTheme.textTertiary)
            
            VStack(spacing: 0) {
                InputField(title: "Service Interval (km)", text: $serviceIntervalKm, icon: "arrow.left.and.right")
            }
            .background(FMSTheme.cardBackground)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMSTheme.borderLight, lineWidth: 1))
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MAINTENANCE NOTES")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(FMSTheme.textTertiary)
            
            TextEditor(text: $notes)
                .frame(minHeight: 120)
                .padding(12)
                .background(FMSTheme.cardBackground)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMSTheme.borderLight, lineWidth: 1))
        }
    }
    
    private func scheduleAutoSave() {
        pendingSave?.cancel()
        pendingSave = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
            if !Task.isCancelled {
                await autoSave()
            }
        }
    }
    
    private func autoSave() async {
        var updatedVehicle = vehicle
        
        // 1. Odometer: only save if changed OR originally present
        if let odoVal = Double(odometer) {
            let originalDisplay = String(format: "%.0f", vehicle.odometer ?? 0)
            if vehicle.odometer != nil || odometer != originalDisplay {
                updatedVehicle.odometer = odoVal
            }
        }
        
        // 2. Last Service Date: only save if changed OR originally present
        if vehicle.lastServiceDate != nil || lastServiceDate != (vehicle.lastServiceDate ?? Date()) {
            updatedVehicle.lastServiceDate = lastServiceDate
        }
        
        // 3. Last Service Odometer: only save if changed OR originally present
        if let lastOdoVal = Double(lastServiceOdometer) {
            let originalDisplay = String(format: "%.0f", vehicle.lastServiceOdometer ?? 0)
            if vehicle.lastServiceOdometer != nil || lastServiceOdometer != originalDisplay {
                updatedVehicle.lastServiceOdometer = lastOdoVal
            }
        }
        
        // 4. Interval KM: only save if changed OR originally present
        if let intervalKm = Double(serviceIntervalKm) {
            let originalDisplay = String(format: "%.0f", vehicle.serviceIntervalKm ?? MaintenanceSettingsStore.shared.intervalKmDouble)
            if vehicle.serviceIntervalKm != nil || serviceIntervalKm != originalDisplay {
                updatedVehicle.serviceIntervalKm = intervalKm
            }
        }
        
        // 5. Notes: always sync if changed
        if notes != (vehicle.notes ?? "") {
            updatedVehicle.notes = notes
        }
        
        do {
            try await fleetViewModel.updateVehicle(updatedVehicle)
            await onUpdate()
        } catch {
            print("Auto-save failed: \(error.localizedDescription)")
        }
    }
}

private struct InputField: View {
    let title: String
    @Binding var text: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(FMSTheme.amber)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(FMSTheme.textTertiary)
                TextField("0", text: $text)
                    .keyboardType(.numberPad)
                    .font(.system(size: 15, weight: .semibold))
            }
        }
        .padding(14)
    }
}
