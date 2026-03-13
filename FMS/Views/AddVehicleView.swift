import SwiftUI

public struct AddVehicleView: View {
    private enum FormMode {
        case add
        case edit
    }
    
    @Environment(\.dismiss) private var dismiss
    @Environment(BannerManager.self) private var bannerManager
    private let mode: FormMode
    private let onSubmit: @MainActor (Vehicle) async throws -> Void
    private let existingVehicleId: String?
    private let existingStatus: String?
    private let existingCreatedBy: String?
    private let existingCreatedAt: Date?
    private let existingPurchaseDateString: String?
    
    @State private var plateNumber = ""
    @State private var chassisNumber = ""
    @State private var manufacturer = ""
    @State private var model = ""
    @State private var fuelType = "Diesel"
    @State private var tankCapacity: Int? = nil
    @State private var carryingCapacity: Int? = nil
    @State private var odometer: Int? = nil
    @State private var isSubmitting = false
    
    private let fuelOptions = ["Diesel", "Petrol", "CNG", "Electric"]
    
    public init(onAdd: @escaping @MainActor (Vehicle) async throws -> Void) {
        self.mode = .add
        self.onSubmit = onAdd
        self.existingVehicleId = nil
        self.existingStatus = nil
        self.existingCreatedBy = nil
        self.existingCreatedAt = nil
        self.existingPurchaseDateString = nil
    }

    public init(vehicle: Vehicle, onUpdate: @escaping @MainActor (Vehicle) async throws -> Void) {
        self.mode = .edit
        self.onSubmit = onUpdate
        self.existingVehicleId = vehicle.id
        self.existingStatus = vehicle.status
        self.existingCreatedBy = vehicle.createdBy
        self.existingCreatedAt = vehicle.createdAt
        self.existingPurchaseDateString = vehicle.purchaseDateString
        _plateNumber = State(initialValue: vehicle.plateNumber)
        _chassisNumber = State(initialValue: vehicle.chassisNumber)
        _manufacturer = State(initialValue: vehicle.manufacturer ?? "")
        _model = State(initialValue: vehicle.model ?? "")
        let fuel = vehicle.fuelType.capitalized
        _fuelType = State(initialValue: fuelOptions.contains(fuel) ? fuel : "Diesel")
        _tankCapacity = State(initialValue: vehicle.fuelTankCapacity > 0 ? Int(vehicle.fuelTankCapacity) : nil)
        _carryingCapacity = State(initialValue: vehicle.carryingCapacity.flatMap { $0 > 0 ? Int($0) : nil })
        _odometer = State(initialValue: vehicle.odometer.flatMap { $0 >= 0 ? Int($0) : nil })
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
                                        numericField(
                                            label: "Fuel Tank (L)",
                                            placeholder: "Liters",
                                            icon: "fuelpump.fill",
                                            value: $tankCapacity,
                                            format: .number,
                                            keyboard: .numberPad
                                        )
                                        
                                        numericField(
                                            label: "Carrying (KG)",
                                            placeholder: "Kilograms",
                                            icon: "shippingbox.fill",
                                            value: $carryingCapacity,
                                            format: .number,
                                            keyboard: .numberPad
                                        )
                                    }
                                    
                                    numericField(
                                        label: "Odometer (KM)",
                                        placeholder: "Kilometers",
                                        icon: "gauge.with.dots.needle.50percent",
                                        value: $odometer,
                                        format: .number,
                                        keyboard: .numberPad
                                    )
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
                                    Text(primaryActionTitle)
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
            .navigationTitle(mode == .add ? "New Vehicle" : "Edit Vehicle")
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
    
    private func numericField<Value: BinaryFloatingPoint>(
        label: String,
        placeholder: String,
        icon: String,
        value: Binding<Value?>,
        format: FloatingPointFormatStyle<Value>,
        keyboard: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(FMSTheme.textSecondary)
                .tracking(0.5)
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(FMSTheme.textTertiary)
                
                TextField(
                    "",
                    value: value,
                    format: format,
                    prompt: Text(placeholder).foregroundColor(FMSTheme.textTertiary)
                )
                .font(.system(size: 15))
                .foregroundColor(FMSTheme.textPrimary)
                .autocorrectionDisabled()
                .keyboardType(keyboard)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(FMSTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(FMSTheme.borderLight, lineWidth: 1)
            )
        }
    }
    
    private func numericField<Value: BinaryInteger>(
        label: String,
        placeholder: String,
        icon: String,
        value: Binding<Value?>,
        format: IntegerFormatStyle<Value>,
        keyboard: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(FMSTheme.textSecondary)
                .tracking(0.5)
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(FMSTheme.textTertiary)
                
                TextField(
                    "",
                    value: value,
                    format: format,
                    prompt: Text(placeholder).foregroundColor(FMSTheme.textTertiary)
                )
                .font(.system(size: 15))
                .foregroundColor(FMSTheme.textPrimary)
                .autocorrectionDisabled()
                .keyboardType(keyboard)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(FMSTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(FMSTheme.borderLight, lineWidth: 1)
            )
        }
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
        
        guard let validatedTankCapacity = tankCapacity, validatedTankCapacity > 0 else {
            showValidationError("Please enter a valid Fuel Tank Capacity greater than 0.")
            return
        }
        
        guard let validatedCarryingCapacity = carryingCapacity, validatedCarryingCapacity > 0 else {
            showValidationError("Please enter a valid Carrying Capacity greater than 0.")
            return
        }
        
        guard let validatedOdometer = odometer, validatedOdometer >= 0 else {
            showValidationError("Please enter a valid Odometer reading.")
            return
        }
        
        // Disable interactions
        isSubmitting = true
        
        let vehicle = Vehicle(
            id: existingVehicleId ?? UUID().uuidString,
            plateNumber: trimmedPlate,
            chassisNumber: trimmedChassis,
            manufacturer: trimmedManufacturer,
            model: trimmedModel,
            fuelType: fuelType.lowercased(),
            fuelTankCapacity: Double(validatedTankCapacity),
            carryingCapacity: Double(validatedCarryingCapacity),
            purchaseDateString: existingPurchaseDateString,
            odometer: Double(validatedOdometer),
            status: existingStatus ?? "inactive",
            createdBy: existingCreatedBy,
            createdAt: existingCreatedAt
        )
        
        Task {
            do {
                try await onSubmit(vehicle)
                await MainActor.run {
                    isSubmitting = false
                    dismiss()
                }
            } catch let error as AddVehicleError {
                await MainActor.run {
                    isSubmitting = false
                    switch error {
                    case .duplicatePlate:
                        showValidationError("Plate Number already exists.")
                    case .duplicateChassis:
                        showValidationError("Chassis Number already exists.")
                    case .networkError:
                        showValidationError("Network error. Please try again.")
                    case .unknown:
                        showValidationError(submitFailureMessage)
                    }
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    showValidationError(submitFailureMessage)
                }
            }
        }
    }
    
    @MainActor
    private func showValidationError(_ message: String) {
        bannerManager.show(type: .error, message: message)
    }

    private var primaryActionTitle: String {
        mode == .add ? "Add Vehicle to Fleet" : "Save Changes"
    }

    private var submitFailureMessage: String {
        mode == .edit ? "Failed to update vehicle. Please try again." : "Failed to add vehicle. Please try again."
    }
}

#Preview {
    AddVehicleView { _ in }
        .environment(BannerManager())
}
