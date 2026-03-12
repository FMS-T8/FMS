import SwiftUI

public struct AddVehicleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BannerManager.self) private var bannerManager
    var onAdd: @MainActor (Vehicle) async -> Bool
    
    @State private var plateNumber = ""
    @State private var chassisNumber = ""
    @State private var manufacturer = ""
    @State private var model = ""
    @State private var fuelType = "Diesel"
    @State private var tankCapacity = ""
    @State private var carryingCapacity = ""
    @State private var odometer = ""
    @State private var isSubmitting = false
    
    private let fuelOptions = ["Diesel", "Petrol", "CNG", "Electric"]
    
    public init(onAdd: @escaping @MainActor (Vehicle) async -> Bool) {
        self.onAdd = onAdd
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                FMSTheme.backgroundPrimary.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Section: Basic Info
                            formSection(title: "Identification") {
                                FMSTextField(
                                    label: "Plate Number",
                                    placeholder: "MH02H0942",
                                    icon: "tag.fill",
                                    text: $plateNumber
                                )
                                .onChange(of: plateNumber) { _, newValue in
                                    let normalized = normalizePlate(newValue)
                                    if normalized != newValue {
                                        plateNumber = normalized
                                    }
                                }
                                
                                FMSTextField(
                                    label: "Chassis Number",
                                    placeholder: "VIN Number",
                                    icon: "number",
                                    text: $chassisNumber
                                )
                                .onChange(of: chassisNumber) { _, newValue in
                                    let normalized = normalizeChassis(newValue)
                                    if normalized != newValue {
                                        chassisNumber = normalized
                                    }
                                }
                            }
                            
                            // Section: Vehicle Details
                            formSection(title: "Specifications") {
                                FMSTextField(
                                    label: "Manufacturer",
                                    placeholder: "Tata, Ashok Leyland",
                                    icon: "building.2.fill",
                                    text: $manufacturer
                                )
                                
                                FMSTextField(
                                    label: "Model",
                                    placeholder: "Prima 5530.S",
                                    icon: "truck.box.fill",
                                    text: $model
                                )
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("FUEL TYPE")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(FMSTheme.textSecondary)
                                        .tracking(0.5)
                                    
                                    HStack {
                                        ForEach(fuelOptions, id: \.self) { option in
                                            Button {
                                                fuelType = option
                                            } label: {
                                                Text(option)
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 10)
                                                    .background(fuelType == option ? FMSTheme.amber : FMSTheme.pillBackground)
                                                    .foregroundColor(fuelType == option ? FMSTheme.obsidian : FMSTheme.textSecondary)
                                                    .cornerRadius(10)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Section: Capacities
                            formSection(title: "Capacities") {
                                VStack(spacing: 16) {
                                    HStack(spacing: 16) {
                                        FMSTextField(
                                            label: "Fuel Tank (L)",
                                            placeholder: "Liters",
                                            icon: "fuelpump.fill",
                                            text: Binding(
                                                get: { tankCapacity },
                                                set: { newValue in
                                                    tankCapacity = newValue.filter { "0123456789.".contains($0) }
                                                }
                                            )
                                        )
                                        .keyboardType(.decimalPad)
                                        
                                        FMSTextField(
                                            label: "Carrying (KG)",
                                            placeholder: "Kilograms",
                                            icon: "shippingbox.fill",
                                            text: Binding(
                                                get: { carryingCapacity },
                                                set: { newValue in
                                                    carryingCapacity = newValue.filter { "0123456789.".contains($0) }
                                                }
                                            )
                                        )
                                        .keyboardType(.decimalPad)
                                    }
                                    
                                    FMSTextField(
                                        label: "Odometer (KM)",
                                        placeholder: "Kilometers",
                                        icon: "gauge.with.dots.needle.50percent",
                                        text: Binding(
                                            get: { odometer },
                                            set: { newValue in
                                                odometer = newValue.filter { "0123456789.".contains($0) }
                                            }
                                        )
                                    )
                                    .keyboardType(.decimalPad)
                                }
                            }
                        }
                        .padding(20)
                    }
                    
                    // Action Button
                    VStack {
                        Button {
                            submitVehicle()
                        } label: {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: FMSTheme.obsidian))
                                } else {
                                    Text("Add Vehicle to Fleet")
                                        .font(.system(size: 17, weight: .bold))
                                }
                            }
                            .foregroundColor(FMSTheme.obsidian)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(FMSTheme.amber)
                            .cornerRadius(16)
                            .shadow(color: FMSTheme.amber.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .disabled(isSubmitting)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                    }
                    .padding(.top, 10)
                    .background(FMSTheme.backgroundPrimary)
                }
            }
            .navigationTitle("New Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                    .foregroundColor(FMSTheme.textSecondary)
                }
            }
        }
    }
    
    private func formSection<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(FMSTheme.textTertiary)
                .tracking(1)
            
            content()
        }
        .padding(20)
        .background(FMSTheme.cardBackground)
        .cornerRadius(20)
        .shadow(color: FMSTheme.shadowSmall, radius: 8, x: 0, y: 4)
    }
    
    private func normalizePlate(_ value: String) -> String {
        value.uppercased().filter { $0.isLetter || $0.isNumber }
    }
    
    private func normalizeChassis(_ value: String) -> String {
        value.uppercased().filter { $0.isLetter || $0.isNumber }
    }
    
    @MainActor
    private func submitVehicle() {
        // Comprehensive validation
        let trimmedPlate = plateNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmedPlate.isEmpty {
            showValidationError("Plate Number is required.")
            return
        }
        
        let trimmedChassis = chassisNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmedChassis.isEmpty {
            showValidationError("Chassis Number is required.")
            return
        }
        
        let trimmedManufacturer = manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedManufacturer.isEmpty {
            showValidationError("Manufacturer is required.")
            return
        }
        
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedModel.isEmpty {
            showValidationError("Model is required.")
            return
        }
        
        guard let validatedTankCapacity = Double(tankCapacity), validatedTankCapacity > 0 else {
            showValidationError("Please enter a valid Fuel Tank Capacity greater than 0.")
            return
        }
        
        guard let validatedCarryingCapacity = Double(carryingCapacity), validatedCarryingCapacity > 0 else {
            showValidationError("Please enter a valid Carrying Capacity greater than 0.")
            return
        }
        
        guard let validatedOdometer = Double(odometer), validatedOdometer >= 0 else {
            showValidationError("Please enter a valid Odometer reading.")
            return
        }
        
        // Disable interactions
        isSubmitting = true
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: Date())
        
        let vehicle = Vehicle(
            id: UUID().uuidString,
            plateNumber: trimmedPlate,
            chassisNumber: trimmedChassis,
            manufacturer: trimmedManufacturer,
            model: trimmedModel,
            fuelType: fuelType.lowercased(),
            fuelTankCapacity: validatedTankCapacity,
            carryingCapacity: validatedCarryingCapacity,
            purchaseDateString: todayString,
            odometer: validatedOdometer,
            status: "inactive",
            createdBy: nil, 
            createdAt: nil
        )
        
        Task {
            let success = await onAdd(vehicle)
            
            await MainActor.run {
                isSubmitting = false
                if success {
                    dismiss()
                } else {
                    showValidationError("Plate Number or Chassis Number already exists.")
                }
            }
        }
    }
    
    @MainActor
    private func showValidationError(_ message: String) {
        bannerManager.show(type: .error, message: message)
    }
}

#Preview {
    AddVehicleView { _ in return true }
}
