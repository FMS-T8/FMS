//
//  CreateOrderView.swift
//  FMS
//
//  Created by user@50 on 16/03/26.
//

import Foundation
import SwiftUI
import MapKit

// MARK: - Location Search ViewModel
@Observable
final class LocationSearchViewModel: NSObject, MKLocalSearchCompleterDelegate {
    var results: [MKLocalSearchCompletion] = []
    var searchText: String = "" {
        didSet { completer.queryFragment = searchText }
    }

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }
}

// MARK: - Location Search Sheet
struct LocationSearchSheet: View {
    let title: String
    @Binding var selectedName: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchVM = LocationSearchViewModel()

    var body: some View {
        NavigationStack {
            List {
                if searchVM.results.isEmpty && searchVM.searchText.isEmpty {
                    ContentUnavailableView(
                        "Search for a location",
                        systemImage: "magnifyingglass",
                        description: Text("Type an address or place name")
                    )
                    .listRowBackground(Color.clear)
                } else if searchVM.results.isEmpty {
                    ContentUnavailableView(
                        "No results",
                        systemImage: "mappin.slash",
                        description: Text("Try a different search term")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(searchVM.results, id: \.self) { result in
                        Button {
                            selectedName = result.title + (result.subtitle.isEmpty ? "" : ", \(result.subtitle)")
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(result.title)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.primary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color(.secondarySystemGroupedBackground))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(
                text: $searchVM.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search address or place"
            )
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Cargo Type Model
enum CargoType: String, CaseIterable {
    case general    = "general"
    case fragile    = "fragile"
    case perishable = "perishable"
    case hazardous  = "hazardous"
    case oversized  = "oversized"

    var label: String {
        switch self {
        case .general:    return "General"
        case .fragile:    return "Fragile"
        case .perishable: return "Perishable"
        case .hazardous:  return "Hazardous"
        case .oversized:  return "Oversized"
        }
    }

    var systemIcon: String {
        switch self {
        case .general:    return "shippingbox.fill"
        case .fragile:    return "hand.raised.fill"
        case .perishable: return "thermometer.snowflake"
        case .hazardous:  return "exclamationmark.triangle.fill"
        case .oversized:  return "cube.box.fill"
        }
    }

    var color: Color {
        switch self {
        case .general:    return .blue
        case .fragile:    return .purple
        case .perishable: return .cyan
        case .hazardous:  return .orange
        case .oversized:  return .brown
        }
    }
}

// MARK: - Priority Model
enum OrderPriority: String, CaseIterable {
    case low    = "low"
    case normal = "normal"
    case high   = "high"
    case urgent = "urgent"

    var label: String { rawValue.capitalized }

    var systemIcon: String {
        switch self {
        case .low:    return "arrow.down.circle.fill"
        case .normal: return "minus.circle.fill"
        case .high:   return "arrow.up.circle.fill"
        case .urgent: return "exclamationmark.2"
        }
    }

    var color: Color {
        switch self {
        case .low:    return .gray
        case .normal: return .blue
        case .high:   return .orange
        case .urgent: return .red
        }
    }
}

// MARK: - CreateOrderView
public struct CreateOrderView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: OrdersViewModel

    // Form State
    @State private var customerName: String = ""
    @State private var customerPhone: String = ""
    @State private var customerEmail: String = ""        // Fix: was missing
    @State private var weightString: String = ""
    @State private var packagesString: String = ""
    @State private var originName: String = ""
    @State private var destinationName: String = ""
    @State private var specialInstructions: String = ""

    // Typed pickers
    @State private var selectedCargoType: CargoType = .general
    @State private var selectedPriority: OrderPriority = .normal

    // Dates
    @State private var pickupDate: Date = Date()
    @State private var deliveryDate: Date = Date().addingTimeInterval(60)

    // Location sheets
    @State private var showingOriginSearch = false
    @State private var showingDestinationSearch = false

    // MARK: - Derived Validation
    private var trimmedOrigin: String {
        originName.trimmingCharacters(in: .whitespaces)
    }
    private var trimmedDestination: String {
        destinationName.trimmingCharacters(in: .whitespaces)
    }
    private var isSameLocation: Bool {
        !trimmedOrigin.isEmpty &&
        !trimmedDestination.isEmpty &&
        trimmedOrigin.lowercased() == trimmedDestination.lowercased()
    }
    private var isFormValid: Bool {
        !customerName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !trimmedOrigin.isEmpty &&
        !trimmedDestination.isEmpty &&
        !isSameLocation &&
        (Double(weightString) ?? 0) > 0 &&
        pickupDate >= Date().addingTimeInterval(-60) &&  // Fix: 60s grace period
        deliveryDate >= pickupDate.addingTimeInterval(60)
    }

    public var body: some View {
        NavigationStack {
            Form {

                // MARK: - Customer Information
                Section(header: Text("Customer Information")) {
                    fmsField(
                        title: "Customer Name *",
                        placeholder: "Enter full name",
                        icon: "person.fill",
                        text: $customerName
                    )
                    fmsField(
                        title: "Phone Number",
                        placeholder: "Enter phone number",
                        icon: "phone.fill",
                        text: $customerPhone,
                        keyboard: .phonePad
                    )
                    fmsField(
                        title: "Email (Optional)",
                        placeholder: "Enter email address",
                        icon: "envelope.fill",
                        text: $customerEmail,
                        keyboard: .emailAddress
                    )
                }
                .listRowBackground(Color(.secondarySystemGroupedBackground))

                // MARK: - Route Details
                Section(header: Text("Route Details")) {
                    locationPickerRow(
                        title: "Origin *",
                        placeholder: "Search pickup location",
                        icon: "building.2.fill",
                        value: originName
                    ) {
                        showingOriginSearch = true
                    }

                    locationPickerRow(
                        title: "Destination *",
                        placeholder: "Search drop-off location",
                        icon: "mappin.and.ellipse",
                        value: destinationName
                    ) {
                        showingDestinationSearch = true
                    }

                    if isSameLocation {
                        Label(
                            "Origin and destination cannot be the same.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.caption)
                        .foregroundColor(.red)
                        .listRowBackground(Color(.secondarySystemGroupedBackground))
                    }

                    DatePicker(
                        "Requested Pickup",
                        selection: $pickupDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .onChange(of: pickupDate) { _, newPickup in
                        if deliveryDate < newPickup.addingTimeInterval(60) {
                            deliveryDate = newPickup.addingTimeInterval(60)
                        }
                    }

                    DatePicker(
                        "Requested Delivery",
                        selection: $deliveryDate,
                        in: pickupDate.addingTimeInterval(60)...,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    if deliveryDate < pickupDate.addingTimeInterval(60) {
                        Label(
                            "Delivery must be at least 1 minute after pickup.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }
                .listRowBackground(Color(.secondarySystemGroupedBackground))

                // MARK: - Cargo Specifications
                Section(header: Text("Cargo Specifications")) {
                    fmsField(
                        title: "Total Weight (kg) *",
                        placeholder: "e.g. 500",
                        icon: "scalemass.fill",
                        text: $weightString,
                        keyboard: .decimalPad
                    )
                    fmsField(
                        title: "Packages (Optional)",
                        placeholder: "Count",
                        icon: "shippingbox.fill",
                        text: $packagesString,
                        keyboard: .numberPad
                    )

                    dropdownRow(
                        title: "Cargo Type",
                        icon: selectedCargoType.systemIcon,
                        iconColor: selectedCargoType.color,
                        selectedLabel: selectedCargoType.label
                    ) {
                        ForEach(CargoType.allCases, id: \.self) { type in
                            Button {
                                selectedCargoType = type
                            } label: {
                                Label(type.label, systemImage: type.systemIcon)
                            }
                        }
                    }

                    dropdownRow(
                        title: "Priority",
                        icon: selectedPriority.systemIcon,
                        iconColor: selectedPriority.color,
                        selectedLabel: selectedPriority.label
                    ) {
                        ForEach(OrderPriority.allCases, id: \.self) { priority in
                            Button {
                                selectedPriority = priority
                            } label: {
                                Label(priority.label, systemImage: priority.systemIcon)
                            }
                        }
                    }
                }
                .listRowBackground(Color(.secondarySystemGroupedBackground))

                // MARK: - Additional Information
                Section(header: Text("Additional Information")) {
                    TextField("Special Instructions...", text: $specialInstructions, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(.vertical, 8)
                }
                .listRowBackground(Color(.secondarySystemGroupedBackground))
            }
            .scrollContentBackground(.visible)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("New Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: submitOrder) {
                        if viewModel.isCreating {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.accentColor)
                        } else {
                            Text("Create")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!isFormValid || viewModel.isCreating)
                }
            }
            // Fix: proper writable Binding instead of .constant()
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $showingOriginSearch) {
                LocationSearchSheet(title: "Pickup Location", selectedName: $originName)
            }
            .sheet(isPresented: $showingDestinationSearch) {
                LocationSearchSheet(title: "Drop-off Location", selectedName: $destinationName)
            }
        }
    }

    // MARK: - Dropdown Row
    // MARK: - Dropdown Row
    @ViewBuilder
    private func dropdownRow<MenuItems: View>(
        title: String,
        icon: String,
        iconColor: Color,
        selectedLabel: String,
        @ViewBuilder menuItems: @escaping () -> MenuItems
    ) -> some View {
        Menu {
            menuItems()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(Color(.secondaryLabel))

                    HStack(spacing: 4) {
                        Text(selectedLabel)
                            .font(.body)
                            .foregroundColor(Color(.label))
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())   // ensures full row area is tappable
        }
        .buttonStyle(.plain)             // prevents Form row from stealing the tap
    }
    
    // MARK: - Location Picker Row
    @ViewBuilder
    private func locationPickerRow(
        title: String,
        placeholder: String,
        icon: String,
        value: String,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(Color(.secondaryLabel))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(Color(.secondaryLabel))

                    Text(value.isEmpty ? placeholder : value)
                        .font(.body)
                        .foregroundColor(value.isEmpty ? Color(.placeholderText) : Color(.label))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Text Field Builder
    @ViewBuilder
    private func fmsField(
        title: String,
        placeholder: String,
        icon: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color(.secondaryLabel))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(Color(.secondaryLabel))

                TextField(placeholder, text: text)
                    .keyboardType(keyboard)
                    .foregroundColor(Color(.label))
                    .autocorrectionDisabled(keyboard == .emailAddress)
                    .textInputAutocapitalization(keyboard == .emailAddress ? .never : .sentences)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Submit Action
    private func submitOrder() {
        guard let weight = Double(weightString), weight > 0 else { return }
        let packages = Int(packagesString)

        let payload = OrderCreatePayload(
            customerName: customerName,
            customerPhone: customerPhone.isEmpty ? nil : customerPhone,
            customerEmail: customerEmail.isEmpty ? nil : customerEmail,  // Fix: now passed
            totalWeightKg: weight,
            totalPackages: packages,
            cargoType: selectedCargoType.rawValue,
            priority: selectedPriority.rawValue,
            originName: originName,
            destinationName: destinationName,
            requestedPickupAt: pickupDate,
            requestedDeliveryAt: deliveryDate,
            specialInstructions: specialInstructions.isEmpty ? nil : specialInstructions
        )

        Task {
            let success = await viewModel.createOrder(payload: payload)
            if success { dismiss() }
        }
    }
}
