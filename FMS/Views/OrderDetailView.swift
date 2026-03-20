//
//  OrderDetailView.swift
//  FMS
//
//  Created by Anish on 17/03/26.
//

import Foundation
import Observation
import SwiftUI
import MapKit
import Supabase

// MARK: - Local Model for Assignment Data
struct OrderAssignmentDetails {
    let driverName: String
    let vehiclePlate: String
}

public struct OrderDetailView: View {
    public let order: Order
    @Bindable var viewModel: OrdersViewModel
    
    @State private var routeSegments: [MKRoute] = []
    @State private var isMapExpanded: Bool = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showingAssignmentSheet = false

    @State private var assignmentDetails: OrderAssignmentDetails? = nil
    @State private var isFetchingAssignment = false
    
    private let markerLabels = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]
    
    public init(order: Order, viewModel: OrdersViewModel) {
        self.order = order
        self.viewModel = viewModel
    }
    
    private var allCoordinates: [CLLocationCoordinate2D] {
        var coords: [CLLocationCoordinate2D] = []
        if let oLat = order.originLat, let oLng = order.originLng {
            coords.append(CLLocationCoordinate2D(latitude: oLat, longitude: oLng))
        }
        if let waypoints = order.waypoints {
            coords.append(contentsOf: waypoints.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) })
        }
        if let dLat = order.destinationLat, let dLng = order.destinationLng {
            coords.append(CLLocationCoordinate2D(latitude: dLat, longitude: dLng))
        }
        return coords
    }
    
    private var totalDistanceKm: Double {
        (routeSegments.reduce(0) { $0 + $1.distance }) / 1000.0
    }
    
    private var totalTravelTime: String {
        let totalSeconds = routeSegments.reduce(0) { $0 + $1.expectedTravelTime }
        if totalSeconds == 0 { return "--" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: totalSeconds) ?? "--"
    }
    
    // Helper to format Date & Time nicely
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Map Preview
                if allCoordinates.count >= 2 {
                    Button(action: { isMapExpanded = true }) {
                        mapContent
                            .frame(height: 220)
                            .cornerRadius(16)
                            .padding(.horizontal, 16)
                            .overlay(
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.black)
                                            .padding(8)
                                            .background(Color.white.opacity(0.9))
                                            .clipShape(Circle())
                                            .shadow(color: .black.opacity(0.15), radius: 4)
                                            .padding(24)
                                    }
                                }
                            )
                            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                }
                
                // MARK: - Estimates
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "point.topleft.down.curvedto.point.bottomright.up.fill")
                                .font(.system(size: 12))
                                .foregroundColor(FMSTheme.amber)
                            Text("Est. Distance")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(FMSTheme.textSecondary)
                        }
                        if routeSegments.isEmpty {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text(String(format: "%.1f km", totalDistanceKm))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(FMSTheme.textPrimary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(FMSTheme.cardBackground)
                    .cornerRadius(16)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 12))
                                .foregroundColor(FMSTheme.amber)
                            Text("Est. Duration")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(FMSTheme.textSecondary)
                        }
                        if routeSegments.isEmpty {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text(totalTravelTime)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(FMSTheme.textPrimary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(FMSTheme.cardBackground)
                    .cornerRadius(16)
                }
                .padding(.horizontal, 16)
                
                // MARK: - Schedule Info
                VStack(spacing: 0) {
                    HStack {
                        Text("Schedule")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(FMSTheme.textPrimary)
                        Spacer()
                    }
                    .padding(16)
                    Divider()
                    
                    detailRow(
                        title: "Pickup",
                        value: order.requestedPickupAt != nil ? formatDateTime(order.requestedPickupAt!) : "Not specified",
                        icon: "arrow.up.circle.fill",
                        iconColor: .blue
                    )
                    Divider().padding(.leading, 48)
                    detailRow(
                        title: "Delivery",
                        value: order.requestedDeliveryAt != nil ? formatDateTime(order.requestedDeliveryAt!) : "Not specified",
                        icon: "arrow.down.circle.fill",
                        iconColor: .green
                    )
                }
                .background(FMSTheme.cardBackground)
                .cornerRadius(16)
                .padding(.horizontal, 16)
                
                // MARK: - Route Timeline
                VStack(spacing: 0) {
                    HStack {
                        Text("Route Timeline")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(FMSTheme.textPrimary)
                        Spacer()
                    }
                    .padding(16)
                    Divider()
                    VStack(alignment: .leading, spacing: 0) {
                        let waypoints = order.waypoints ?? []
                        let totalStops = waypoints.count + 2
                        
                        routeStopRow(label: "A", color: .blue, title: "Pickup Location", address: order.originName, isLast: false)
                        ForEach(Array(waypoints.enumerated()), id: \.offset) { index, waypoint in
                            routeStopRow(
                                label: markerLabels[min(index + 1, markerLabels.count - 1)],
                                color: FMSTheme.amber,
                                title: "Stop \(index + 1)",
                                address: waypoint.name,
                                isLast: false
                            )
                        }
                        routeStopRow(
                            label: markerLabels[min(totalStops - 1, markerLabels.count - 1)],
                            color: .green,
                            title: "Delivery Location",
                            address: order.destinationName,
                            isLast: true
                        )
                    }
                    .padding(16)
                }
                .background(FMSTheme.cardBackground)
                .cornerRadius(16)
                .padding(.horizontal, 16)
                
                // MARK: - Assignment Status
                VStack(spacing: 0) {
                    HStack {
                        Text("Assignment Details")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(FMSTheme.textPrimary)
                        Spacer()
                        if assignmentDetails == nil && order.isPending {
                            Text("Unassigned")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(FMSTheme.alertOrange)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(FMSTheme.alertOrange.opacity(0.15))
                                .clipShape(Capsule())
                        } else {
                            Text("Assigned")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.green)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(16)
                    Divider()
                    
                    if isFetchingAssignment {
                        HStack { Spacer(); ProgressView().padding(); Spacer() }
                    } else if let details = assignmentDetails {
                        detailRow(title: "Driver", value: details.driverName, icon: "steeringwheel")
                        Divider().padding(.leading, 48)
                        detailRow(title: "Vehicle", value: details.vehiclePlate, icon: "truck.box.fill")
                    } else if order.isPending {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(FMSTheme.alertOrange)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Action Required")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(FMSTheme.textPrimary)
                                Text("This order requires a driver and a vehicle to be dispatched.")
                                    .font(.system(size: 13))
                                    .foregroundColor(FMSTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }
                        .padding(16)
                    } else {
                        detailRow(
                            title: "Status",
                            value: order.statusLabel,
                            icon: order.isOngoing ? "truck.box.fill" : "calendar.badge.clock"
                        )
                    }
                }
                .background(FMSTheme.cardBackground)
                .cornerRadius(16)
                .padding(.horizontal, 16)
                
                // MARK: - Customer & Cargo Info
                VStack(spacing: 0) {
                    detailRow(title: "Customer", value: order.customerName, icon: "person.fill")
                    Divider().padding(.leading, 48)
                    if let phone = order.customerPhone {
                        detailRow(title: "Phone", value: phone, icon: "phone.fill")
                        Divider().padding(.leading, 48)
                    }
                    detailRow(title: "Cargo Type", value: order.cargoType?.capitalized ?? "General", icon: "shippingbox.fill")
                    Divider().padding(.leading, 48)
                    detailRow(title: "Total Weight", value: "\(String(format: "%.0f", order.totalWeightKg)) kg", icon: "scalemass.fill")
                }
                .background(FMSTheme.cardBackground)
                .cornerRadius(16)
                .padding(.horizontal, 16)
                
                // MARK: - Additional Notes
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "note.text")
                            .foregroundColor(FMSTheme.amber)
                        Text("Additional Notes")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(FMSTheme.textPrimary)
                        Spacer()
                    }
                    
                    if let notes = order.specialInstructions, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(notes)
                            .font(.system(size: 15))
                            .foregroundColor(FMSTheme.textSecondary)
                            // Allows long notes to wrap naturally
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(4)
                    } else {
                        Text("No additional notes provided.")
                            .font(.system(size: 15))
                            .foregroundColor(FMSTheme.textTertiary)
                            .italic()
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FMSTheme.cardBackground)
                .cornerRadius(16)
                .padding(.horizontal, 16)
                
                // MARK: - Action Button
                if order.isPending && assignmentDetails == nil {
                    Button(action: { showingAssignmentSheet = true }) {
                        Text("Assign Trip to Driver")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(FMSTheme.backgroundPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(FMSTheme.amber)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
            }
            .padding(.vertical, 20)
        }
        .background(FMSTheme.backgroundPrimary.ignoresSafeArea())
        .navigationTitle(order.orderNumber ?? "Order Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await fetchRoutes()
            await fetchAssignmentDetails()
        }
        .onChange(of: showingAssignmentSheet) { _, isShowing in
            if !isShowing { Task { await fetchAssignmentDetails() } }
        }
        .sheet(isPresented: $isMapExpanded) {
            NavigationStack {
                mapContent
                    .ignoresSafeArea(edges: .bottom)
                    .navigationTitle("Route Overview")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { isMapExpanded = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingAssignmentSheet) {
            DriverVehicleAssignmentSheet(
                orderId: order.id,
                targetDate: order.requestedPickupAt,
                viewModel: viewModel
            )
        }
    }
    
    private var mapContent: some View {
        Map(position: $cameraPosition) {
            ForEach(Array(routeSegments.enumerated()), id: \.offset) { index, route in
                MapPolyline(route).stroke(FMSTheme.amber, lineWidth: 5)
            }
            ForEach(Array(allCoordinates.enumerated()), id: \.offset) { index, coordinate in
                Annotation("", coordinate: coordinate) {
                    Text(markerLabels[min(index, markerLabels.count - 1)])
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            index == 0 ? Color.blue :
                            (index == allCoordinates.count - 1 ? Color.green : FMSTheme.amber)
                        )
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .shadow(radius: 3)
                }
            }
        }
        .allowsHitTesting(isMapExpanded)
    }
    
    @ViewBuilder
    private func routeStopRow(label: String, color: Color, title: String, address: String?, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                Text(label)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(color)
                    .clipShape(Circle())
                if !isLast {
                    Rectangle()
                        .fill(FMSTheme.borderLight)
                        .frame(width: 2)
                        .padding(.top, 4)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(FMSTheme.textSecondary)
                Text(address ?? "Unknown")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(FMSTheme.textPrimary)
                    .padding(.bottom, isLast ? 0 : 24)
            }
            .padding(.top, 2)
            Spacer()
        }
        .fixedSize(horizontal: false, vertical: true)
    }
    
    @ViewBuilder
    private func detailRow(title: String, value: String, icon: String, iconColor: Color? = nil) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(iconColor ?? FMSTheme.textTertiary)
                .frame(width: 20)
            
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(FMSTheme.textSecondary)
            
            Spacer(minLength: 16)
            
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(FMSTheme.textPrimary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
    }
    
    // MARK: - Route Calculation
    private func fetchRoutes() async {
        let coords = allCoordinates
        guard coords.count >= 2 else { return }
        var segments: [MKRoute] = []

        for i in 0..<(coords.count - 1) {
            let request = MKDirections.Request()

            request.source = MKMapItem(
                placemark: MKPlacemark(coordinate: coords[i])
            )
            request.destination = MKMapItem(
                placemark: MKPlacemark(coordinate: coords[i + 1])
            )
            request.transportType = .automobile

            do {
                let directions = MKDirections(request: request)
                let response = try await directions.calculate()
                if let route = response.routes.first { segments.append(route) }
            } catch {
                print("Failed to calculate route segment \(i): \(error)")
            }
        }

        await MainActor.run { self.routeSegments = segments }
    }
    
    // MARK: - Assignment Fetch
    private func fetchAssignmentDetails() async {
        await MainActor.run { isFetchingAssignment = true }
        do {
            struct TripQuery: Decodable { let driver_id: String?; let vehicle_id: String? }
            let trips: [TripQuery] = try await SupabaseService.shared.client
                .from("trips")
                .select("driver_id, vehicle_id")
                .eq("order_id", value: order.id)
                .execute()
                .value
            
            if let trip = trips.first, let dId = trip.driver_id, let vId = trip.vehicle_id {
                struct DriverQuery: Decodable { let name: String }
                let drivers: [DriverQuery] = try await SupabaseService.shared.client
                    .from("users")
                    .select("name")
                    .eq("id", value: dId)
                    .execute()
                    .value
                
                struct VehicleQuery: Decodable { let plate_number: String }
                let vehicles: [VehicleQuery] = try await SupabaseService.shared.client
                    .from("vehicles")
                    .select("plate_number")
                    .eq("id", value: vId)
                    .execute()
                    .value
                
                if let driver = drivers.first, let vehicle = vehicles.first {
                    await MainActor.run {
                        self.assignmentDetails = OrderAssignmentDetails(
                            driverName: driver.name,
                            vehiclePlate: vehicle.plate_number
                        )
                    }
                }
            }
        } catch {
            print("Failed to fetch assignment details: \(error)")
        }
        await MainActor.run { isFetchingAssignment = false }
    }
}

// MARK: - Assignment Sheet
struct DriverVehicleAssignmentSheet: View {
    let orderId: String
    let targetDate: Date?
    @Bindable var viewModel: OrdersViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDriverId: String?
    @State private var selectedVehicleId: String?
    
    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Live Resources")) {
                    Picker("Select Driver", selection: $selectedDriverId) {
                        Text("None").tag(String?.none)
                        ForEach(viewModel.availableDrivers) { driver in
                            Text(driver.name).tag(String?.some(driver.id))
                        }
                    }
                    Picker("Select Vehicle", selection: $selectedVehicleId) {
                        Text("None").tag(String?.none)
                        ForEach(viewModel.availableVehicles) { vehicle in
                            Text("\(vehicle.plateNumber) (\(vehicle.model ?? "Van"))").tag(String?.some(vehicle.id))
                        }
                    }
                }
                
                Button(action: {
                    if let dId = selectedDriverId, let vId = selectedVehicleId {
                        isSubmitting = true
                        Task {
                            do {
                                try await viewModel.assignTrip(orderId: orderId, driverId: dId, vehicleId: vId)
                                await MainActor.run {
                                    isSubmitting = false
                                    dismiss()
                                }
                            } catch {
                                await MainActor.run {
                                    isSubmitting = false
                                    errorMessage = error.localizedDescription
                                    showError = true
                                }
                            }
                        }
                    }
                }) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Dispatch Trip")
                            .frame(maxWidth: .infinity)
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .disabled(selectedDriverId == nil || selectedVehicleId == nil || isSubmitting)
                .listRowBackground(FMSTheme.amber)
                .foregroundColor(FMSTheme.backgroundPrimary)
            }
            .navigationTitle("Assign Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Assignment Failed", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred while dispatching the trip.")
            }
            .task {
                await viewModel.fetchAvailableResources(for: targetDate)
            }
        }
    }
}
