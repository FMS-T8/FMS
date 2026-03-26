//
//  CreateOrderView.swift
//  FMS
//
//  Created by user@50 on 16/03/26.
//

import Foundation
import SwiftUI
import MapKit

@Observable
final class LocationSearchViewModel: NSObject, MKLocalSearchCompleterDelegate {
    var results: [MKLocalSearchCompletion] = []
    var searchText: String = "" { didSet { completer.queryFragment = searchText } }
    private let completer = MKLocalSearchCompleter()
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) { results = completer.results }
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) { results = [] }
}

struct LocationSearchSheet: View {
    let title: String
    var onSelect: (String, Double?, Double?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchVM = LocationSearchViewModel()
    @State private var isResolving = false

    var body: some View {
        NavigationStack {
            List {
                if searchVM.results.isEmpty && searchVM.searchText.isEmpty {
                    ContentUnavailableView("Search for a location", systemImage: "magnifyingglass", description: Text("Type an address or place name")).listRowBackground(Color.clear)
                } else if searchVM.results.isEmpty {
                    ContentUnavailableView("No results", systemImage: "mappin.slash", description: Text("Try a different search term")).listRowBackground(Color.clear)
                } else {
                    ForEach(searchVM.results, id: \.self) { result in
                        Button { resolveLocation(result) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(result.title).font(.system(size: 15, weight: .medium)).foregroundColor(.primary)
                                    if !result.subtitle.isEmpty { Text(result.subtitle).font(.system(size: 13)).foregroundColor(.secondary) }
                                }
                                Spacer()
                                if isResolving { ProgressView().scaleEffect(0.8) }
                            }
                            .padding(.vertical, 4)
                        }
                        .disabled(isResolving)
                        .listRowBackground(Color(.secondarySystemGroupedBackground))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchVM.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search address or place")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } } }
        }
    }
    
    private func resolveLocation(_ result: MKLocalSearchCompletion) {
        isResolving = true
        let request = MKLocalSearch.Request(completion: result)
        MKLocalSearch(request: request).start { response, _ in
            Task { @MainActor in
                isResolving = false
                let name = result.title + (result.subtitle.isEmpty ? "" : ", \(result.subtitle)")
                if let coordinate = response?.mapItems.first?.location.coordinate {
                    onSelect(name, coordinate.latitude, coordinate.longitude)
                } else {
                    onSelect(name, nil, nil)
                }
                dismiss()
            }
        }
    }
}

enum CargoType: String, CaseIterable {
    case general = "general", fragile = "fragile", perishable = "perishable", hazardous = "hazardous", oversized = "oversized"
    var label: String { rawValue.capitalized }
    var systemIcon: String {
        switch self { case .general: return "shippingbox.fill"; case .fragile: return "hand.raised.fill"; case .perishable: return "thermometer.snowflake"; case .hazardous: return "exclamationmark.triangle.fill"; case .oversized: return "cube.box.fill" }
    }
    var color: Color {
        switch self { case .general: return .blue; case .fragile: return .purple; case .perishable: return .cyan; case .hazardous: return .orange; case .oversized: return .brown }
    }
}

enum OrderPriority: String, CaseIterable {
    case low = "low", normal = "normal", high = "high", urgent = "urgent"
    var label: String { rawValue.capitalized }
    var systemIcon: String {
        switch self { case .low: return "arrow.down.circle.fill"; case .normal: return "minus.circle.fill"; case .high: return "arrow.up.circle.fill"; case .urgent: return "exclamationmark.2" }
    }
    var color: Color {
        switch self { case .low: return .gray; case .normal: return .blue; case .high: return .orange; case .urgent: return .red }
    }
}

enum AssignmentPreference: String, CaseIterable {
    case later = "Assign Later"
    case now = "Assign Now"
}

public struct CreateOrderView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: OrdersViewModel

    @State private var customerName: String = ""
    @State private var customerPhone: String = ""
    @State private var customerEmail: String = ""
    
    @State private var originName: String = ""
    @State private var originLat: Double? = nil
    @State private var originLng: Double? = nil
    @State private var waypoints: [Waypoint] = []
    @State private var destinationName: String = ""
    @State private var destinationLat: Double? = nil
    @State private var destinationLng: Double? = nil
    @State private var pickupDate: Date = Date().addingTimeInterval(900)
    @State private var deliveryDate: Date = Date().addingTimeInterval(4500)
    
    @State private var assignmentPref: AssignmentPreference = .later
    @State private var selectedDriverId: String? = nil
    @State private var selectedDriverName: String = ""
    @State private var selectedVehicleId: String? = nil
    @State private var selectedVehicleName: String = ""
    
    @State private var weightString: String = ""
    @State private var packagesString: String = ""
    @State private var selectedCargoType: CargoType = .general
    @State private var selectedPriority: OrderPriority = .normal
    @State private var specialInstructions: String = ""

    @State private var showingOriginSearch = false
    @State private var showingDestinationSearch = false
    @State private var showingWaypointSearch = false
    @State private var showingDriverSearch = false
    @State private var showingVehicleSearch = false
    @State private var showingError = false
    @FocusState private var focusedField: String?

    private var trimmedOrigin: String { originName.trimmingCharacters(in: .whitespaces) }
    private var trimmedDestination: String { destinationName.trimmingCharacters(in: .whitespaces) }
    private var isSameLocation: Bool { !trimmedOrigin.isEmpty && !trimmedDestination.isEmpty && trimmedOrigin.lowercased() == trimmedDestination.lowercased() }
    private var geofencePoints: [GeofenceMapPoint] {
        var points: [GeofenceMapPoint] = []

        if let originLat, let originLng {
            points.append(
                GeofenceMapPoint(
                    kind: .pickup,
                    name: originName.isEmpty ? "Pickup" : originName,
                    coordinate: CLLocationCoordinate2D(latitude: originLat, longitude: originLng)
                )
            )
        }

        for (index, waypoint) in waypoints.enumerated() {
            points.append(
                GeofenceMapPoint(
                    kind: .stop(index: index),
                    name: waypoint.name,
                    coordinate: CLLocationCoordinate2D(latitude: waypoint.lat, longitude: waypoint.lng)
                )
            )
        }

        if let destinationLat, let destinationLng {
            points.append(
                GeofenceMapPoint(
                    kind: .destination,
                    name: destinationName.isEmpty ? "Destination" : destinationName,
                    coordinate: CLLocationCoordinate2D(latitude: destinationLat, longitude: destinationLng)
                )
            )
        }

        return points
    }
    
    private var isPhoneValid: Bool {
        let count = customerPhone.filter { $0.isNumber }.count
        return count == 10
    }
    
    private var isCapacityValid: Bool {
        guard assignmentPref == .now,
              let vehicleId = selectedVehicleId,
              let vehicle = viewModel.availableVehicles.first(where: { $0.id == vehicleId }),
              let capacity = vehicle.carryingCapacity,
              let weight = Double(weightString) else { return true }
        return weight <= capacity
    }
    
    private var isFormValid: Bool {
        let baseValid = !customerName.trimmingCharacters(in: .whitespaces).isEmpty &&
            !trimmedOrigin.isEmpty && !trimmedDestination.isEmpty && !isSameLocation &&
            (Double(weightString) ?? 0) > 0 &&
            pickupDate >= Date().addingTimeInterval(-60) &&
            deliveryDate >= pickupDate.addingTimeInterval(60)
        
        if assignmentPref == .now {
            return baseValid && selectedDriverId != nil && selectedVehicleId != nil
        }
        return baseValid
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Customer Information")) {
                    fmsField(title: "Customer Name *", placeholder: "Enter full name", icon: "person.fill", text: $customerName)
                        .focused($focusedField, equals: "customerName")
                    
                    VStack(alignment: .leading, spacing: 4) {
                        fmsField(title: "Phone Number * (10 digits)", placeholder: "Enter phone number", icon: "phone.fill", text: $customerPhone, keyboard: .phonePad)
                            .focused($focusedField, equals: "customerPhone")
                        
                        if !customerPhone.isEmpty && !isPhoneValid {
                            Text("Must be exactly 10 digits").font(.caption2).foregroundColor(FMSTheme.alertRed)
                        }
                    }
                    
                    fmsField(title: "Email (Optional)", placeholder: "Enter email address", icon: "envelope.fill", text: $customerEmail, keyboard: .emailAddress)
                        .focused($focusedField, equals: "customerEmail")
                }
                .listRowBackground(Color(.secondarySystemGroupedBackground))

                Section(header: Text("Route Details")) {
                    locationPickerRow(title: "Origin *", placeholder: "Search pickup location", icon: "building.2.fill", value: originName) { showingOriginSearch = true }
                    
                    ForEach(waypoints.indices, id: \.self) { index in
                        HStack {
                            Image(systemName: "smallcircle.filled.circle.fill").foregroundColor(FMSTheme.amber).frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Stop \(index + 1)").font(.caption).foregroundColor(Color(.secondaryLabel))
                                Text(waypoints[index].name).font(.body).lineLimit(1)
                            }
                            Spacer()
                            Button(role: .destructive) { waypoints.remove(at: index) } label: { Image(systemName: "minus.circle.fill").foregroundColor(FMSTheme.alertRed) }.buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }

                    Button(action: { showingWaypointSearch = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill").foregroundColor(FMSTheme.amber)
                            Text("Add Stop").font(.system(size: 15, weight: .medium)).foregroundColor(Color(.label))
                        }
                        .padding(.vertical, 4)
                    }

                    locationPickerRow(title: "Destination *", placeholder: "Search drop-off location", icon: "mappin.and.ellipse", value: destinationName) { showingDestinationSearch = true }

                    if isSameLocation { Label("Origin and destination cannot be the same.", systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundColor(.red).listRowBackground(Color(.secondarySystemGroupedBackground)) }

                    if !geofencePoints.isEmpty {
                        GeofenceSelectorMap(points: geofencePoints, radiusMeters: 400)
                            .padding(.vertical, 6)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }

                    DatePicker("Requested Pickup", selection: $pickupDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .onChange(of: pickupDate) { _, newPickup in if deliveryDate < newPickup.addingTimeInterval(60) { deliveryDate = newPickup.addingTimeInterval(60) } }
                    DatePicker("Requested Delivery", selection: $deliveryDate, in: pickupDate.addingTimeInterval(60)..., displayedComponents: [.date, .hourAndMinute])
                }
                .listRowBackground(Color(.secondarySystemGroupedBackground))

                Section(header: Text("Driver & Vehicle Assignment")) {
                    Picker("Assignment Preference", selection: $assignmentPref) {
                        Text("Assign Later").tag(AssignmentPreference.later)
                        Text("Assign Now").tag(AssignmentPreference.now)
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                    
                    if assignmentPref == .now {
                        locationPickerRow(title: "Driver *", placeholder: "Select available driver", icon: "steeringwheel", value: selectedDriverName) {
                            focusedField = nil
                            showingDriverSearch = true
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            locationPickerRow(title: "Vehicle *", placeholder: "Select available vehicle", icon: "truck.box.fill", value: selectedVehicleName) {
                                focusedField = nil
                                showingVehicleSearch = true
                            }
                            if !isCapacityValid, let vehicle = viewModel.availableVehicles.first(where: { $0.id == selectedVehicleId }), let capacity = vehicle.carryingCapacity {
                                Label("Max payload for this vehicle is \(String(format: "%.0f", capacity))kg", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundColor(FMSTheme.alertRed)
                                    .padding(.leading, 32)
                            }
                        }
                    }
                }
                .listRowBackground(Color(.secondarySystemGroupedBackground))

                Section(header: Text("Cargo Specifications")) {
                    fmsField(title: "Total Weight (kg) *", placeholder: "e.g. 500", icon: "scalemass.fill", text: $weightString, keyboard: .decimalPad)
                        .focused($focusedField, equals: "weight")
                    fmsField(title: "Packages (Optional)", placeholder: "Count", icon: "shippingbox.fill", text: $packagesString, keyboard: .numberPad)
                        .focused($focusedField, equals: "packages")
                    dropdownRow(title: "Cargo Type", icon: selectedCargoType.systemIcon, iconColor: selectedCargoType.color, selectedLabel: selectedCargoType.label) {
                        ForEach(CargoType.allCases, id: \.self) { type in Button { selectedCargoType = type } label: { Label(type.label, systemImage: type.systemIcon) } }
                    }
                    dropdownRow(title: "Priority", icon: selectedPriority.systemIcon, iconColor: selectedPriority.color, selectedLabel: selectedPriority.label) {
                        ForEach(OrderPriority.allCases, id: \.self) { priority in Button { selectedPriority = priority } label: { Label(priority.label, systemImage: priority.systemIcon) } }
                    }
                }
                .listRowBackground(Color(.secondarySystemGroupedBackground))

                Section(header: Text("Additional Information")) {
                    TextField("Special Instructions...", text: $specialInstructions, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(.vertical, 8)
                        .focused($focusedField, equals: "instructions")
                }
                .listRowBackground(Color(.secondarySystemGroupedBackground))
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { focusedField = nil }
            .scrollContentBackground(.visible)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("New Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: submitOrder) {
                        if viewModel.isCreating { ProgressView().progressViewStyle(.circular).tint(.accentColor) } else { Text("Create").fontWeight(.semibold) }
                    }.disabled(!isFormValid || viewModel.isCreating)
                }
            }
            .task {
                // Fetch resources based on the default date when the view opens
                await viewModel.fetchAvailableResources(for: pickupDate)
            }
            // Listen to date changes to recalculate driver availability dynamically
            .onChange(of: pickupDate) { _, newDate in
                Task {
                    await viewModel.fetchAvailableResources(for: newDate)
                    
                    // Clear out the selection if that driver/vehicle is no longer available on the new date
                    if !viewModel.availableDrivers.contains(where: { $0.id == selectedDriverId }) {
                        selectedDriverId = nil
                        selectedDriverName = ""
                    }
                    if !viewModel.availableVehicles.contains(where: { $0.id == selectedVehicleId }) {
                        selectedVehicleId = nil
                        selectedVehicleName = ""
                    }
                }
            }
            .sheet(isPresented: $showingOriginSearch) {
                LocationSearchSheet(title: "Pickup Location") { name, lat, lng in
                    if let lat = lat, let lng = lng {
                        self.originName = name
                        self.originLat = lat
                        self.originLng = lng
                    }
                }
            }
            .sheet(isPresented: $showingDestinationSearch) {
                LocationSearchSheet(title: "Drop-off Location") { name, lat, lng in
                    if let lat = lat, let lng = lng {
                        self.destinationName = name
                        self.destinationLat = lat
                        self.destinationLng = lng
                    }
                }
            }
            .sheet(isPresented: $showingWaypointSearch) {
                LocationSearchSheet(title: "Add Stop") { name, lat, lng in
                    if let lat = lat, let lng = lng {
                        waypoints.append(Waypoint(name: name, lat: lat, lng: lng))
                    }
                }
            }
            .sheet(isPresented: $showingDriverSearch) {
                ResourcePickerSheet(title: "Select Driver", icon: "person.circle.fill", items: viewModel.availableDrivers.map { ($0.id, $0.name) }) { id, name in
                    self.selectedDriverId = id; self.selectedDriverName = name
                }
            }
            .sheet(isPresented: $showingVehicleSearch) {
                ResourcePickerSheet(title: "Select Vehicle", icon: "truck.box.fill", items: viewModel.availableVehicles.map { ($0.id, "\($0.plateNumber) (\($0.manufacturer ?? "") \($0.model ?? ""))") }) { id, name in
                    self.selectedVehicleId = id; self.selectedVehicleName = name
                }
            }
            .alert("Error Creating Order", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred.")
            }
        }
    }

    @ViewBuilder
    private func dropdownRow<MenuItems: View>(title: String, icon: String, iconColor: Color, selectedLabel: String, @ViewBuilder menuItems: @escaping () -> MenuItems) -> some View {
        Menu { menuItems() } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundColor(iconColor).frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.caption).foregroundColor(Color(.secondaryLabel))
                    HStack(spacing: 4) { Text(selectedLabel).font(.body).foregroundColor(Color(.label)); Spacer(); Image(systemName: "chevron.up.chevron.down").font(.system(size: 12, weight: .medium)).foregroundColor(Color(.tertiaryLabel)) }
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func locationPickerRow(title: String, placeholder: String, icon: String, value: String, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundColor(Color(.secondaryLabel)).frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.caption).foregroundColor(Color(.secondaryLabel))
                    Text(value.isEmpty ? placeholder : value).font(.body).foregroundColor(value.isEmpty ? Color(.placeholderText) : Color(.label)).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14)).foregroundColor(Color(.tertiaryLabel))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func fmsField(title: String, placeholder: String, icon: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(Color(.secondaryLabel)).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundColor(Color(.secondaryLabel))
                TextField(placeholder, text: text).keyboardType(keyboard).foregroundColor(Color(.label)).autocorrectionDisabled(keyboard == .emailAddress).textInputAutocapitalization(keyboard == .emailAddress ? .never : .sentences)
            }
        }
        .padding(.vertical, 4)
    }

    private func submitOrder() {
        focusedField = nil
        
        // Final validations with alerts
        if !isPhoneValid {
            viewModel.errorMessage = "Customer phone number must be exactly 10 digits."
            showingError = true
            return
        }
        
        if assignmentPref == .now && !isCapacityValid {
            if let vehicle = viewModel.availableVehicles.first(where: { $0.id == selectedVehicleId }), let capacity = vehicle.carryingCapacity {
                viewModel.errorMessage = "Selected vehicle (#\(vehicle.plateNumber)) has a maximum capacity of \(String(format: "%.0f", capacity))kg. The order weight exceeds this limit."
            } else {
                viewModel.errorMessage = "Payload exceeds vehicle capacity."
            }
            showingError = true
            return
        }
        
        guard let weight = Double(weightString), weight > 0 else { return }
        
        let payload = OrderCreatePayload(
            customerName: customerName,
            customerPhone: customerPhone.isEmpty ? nil : customerPhone,
            customerEmail: customerEmail.isEmpty ? nil : customerEmail,
            totalWeightKg: weight,
            totalPackages: Int(packagesString),
            cargoType: selectedCargoType.rawValue,
            priority: selectedPriority.rawValue,
            originName: originName,
            originLat: originLat,
            originLng: originLng,
            destinationName: destinationName,
            destinationLat: destinationLat,
            destinationLng: destinationLng,
            waypoints: waypoints.isEmpty ? nil : waypoints,
            requestedPickupAt: pickupDate,
            requestedDeliveryAt: deliveryDate,
            specialInstructions: specialInstructions.isEmpty ? nil : specialInstructions
        )

        Task {
            let success = await viewModel.createOrder(
                payload: payload,
                driverId: assignmentPref == .now ? selectedDriverId : nil,
                vehicleId: assignmentPref == .now ? selectedVehicleId : nil
            )
            if success {
                dismiss()
            } else {
                showingError = true
            }
        }
    }
}

struct ResourcePickerSheet: View {
    let title: String
    let icon: String
    let items: [(id: String, name: String)]
    var onSelect: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if items.isEmpty {
                    ContentUnavailableView("No Resources Available", systemImage: "calendar.badge.exclamationmark", description: Text("There are no unassigned drivers or vehicles available for this date."))
                } else {
                    ForEach(items, id: \.id) { item in
                        Button {
                            onSelect(item.id, item.name)
                            dismiss()
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: icon).foregroundColor(FMSTheme.textTertiary).font(.title2)
                                Text(item.name).font(.system(size: 16, weight: .medium)).foregroundColor(FMSTheme.textPrimary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } } }
        }
    }
}
