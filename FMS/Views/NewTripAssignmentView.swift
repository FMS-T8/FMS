//
//  NewTripAssignmentView.swift
//  FMS
//
//  Created by NJ on 12/03/26.
//

import SwiftUI
import CoreLocation
import Supabase

public struct NewTripAssignmentView: View {
    let trip: Trip
    @Bindable var viewModel: DriverDashboardViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var showIssueReport = false
    @State private var showPreTripInspection = false
    @State private var showPostTripInspection = false
    @State private var preTripInspectionCompleted = false
    @State private var postTripInspectionCompleted = false
    @State private var showLocationConfirmation = false
    @State private var tripVehicle: Vehicle? = nil
    @State private var orderNumber: String? = nil
    @State private var orderWaypoints: [Waypoint] = []
    @State private var fetchError: String? = nil

    private var activeStops: [MockStop] {
        var stops: [MockStop] = []
        if let startLat = trip.startLat, let startLng = trip.startLng {
            stops.append(MockStop(
                title: trip.startName ?? "Origin",
                address: "",
                expectedTime: trip.startTime.map { formatDateTime($0) } ?? "Scheduled",
                stopType: .pickup,
                coordinate: CLLocationCoordinate2D(latitude: startLat, longitude: startLng)
            ))
        }
        for wp in orderWaypoints {
            stops.append(MockStop(
                title: wp.name,
                address: "",
                expectedTime: "Via Stop",
                stopType: .waypoint,
                coordinate: CLLocationCoordinate2D(latitude: wp.lat, longitude: wp.lng)
            ))
        }
        if let endLat = trip.endLat, let endLng = trip.endLng {
            stops.append(MockStop(
                title: trip.endName ?? "Destination",
                address: "",
                expectedTime: trip.endTime.map { formatDateTime($0) } ?? "Estimated",
                stopType: .dropOff,
                coordinate: CLLocationCoordinate2D(latitude: endLat, longitude: endLng)
            ))
        }
        return stops
    }

    public init(trip: Trip, viewModel: DriverDashboardViewModel) {
        self.trip = trip
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                MapCard(stops: activeStops)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)

                // Inline error banner shown when vehicle or order data failed to load
                if let error = fetchError {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(FMSTheme.alertOrange)
                        Text(error)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(FMSTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button {
                            fetchError = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(FMSTheme.textSecondary)
                        }
                    }
                    .padding(12)
                    .background(FMSTheme.alertOrange.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(FMSTheme.alertOrange.opacity(0.3), lineWidth: 1)
                    )
                }

                statsSection
                assignedVehicleCard
                itinerarySection
                tripInfoCard

                if trip.shipmentDescription != nil || trip.shipmentWeightKg != nil ||
                   trip.shipmentPackageCount != nil || trip.fragile == true ||
                   trip.specialInstructions != nil {
                    shipmentCard
                }

                Spacer().frame(height: 40)
            }
            .padding(16)
        }
        .background(FMSTheme.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Trip Assignment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await fetchTripVehicle()
        }
        .safeAreaInset(edge: .bottom) {
            bottomStickyButton
        }
        .sheet(isPresented: $showIssueReport) {
            IssueReportView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $showPreTripInspection) {
            if let vehicle = viewModel.assignedVehicle {
                InspectionChecklistView(
                    type: .preTrip,
                    vehicleId: vehicle.id,
                    driverId: viewModel.driver.id,
                    onCompletion: { preTripInspectionCompleted = true }
                )
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(FMSTheme.alertOrange)
                    Text("No assigned vehicle found.")
                        .font(.headline)
                    Button("Dismiss") { showPreTripInspection = false }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .fullScreenCover(isPresented: $showPostTripInspection) {
            if let vehicle = viewModel.assignedVehicle {
                InspectionChecklistView(
                    type: .postTrip,
                    vehicleId: vehicle.id,
                    driverId: viewModel.driver.id,
                    onCompletion: { postTripInspectionCompleted = true }
                )
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(FMSTheme.alertOrange)
                    Text("No assigned vehicle found.")
                        .font(.headline)
                    Button("Dismiss") { showPostTripInspection = false }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .onChange(of: showPreTripInspection) { _, isShowing in
            if !isShowing {
                if preTripInspectionCompleted {
                    viewModel.startTrip(trip)
                    openAppleMaps()
                    dismiss()
                    showLocationConfirmation = true
                }
                preTripInspectionCompleted = false
            }
        }
        .fullScreenCover(isPresented: $showLocationConfirmation) {
            LocationTrackingConfirmationView(trip: trip)
        }
        .onChange(of: showLocationConfirmation) { _, isShowing in
            if !isShowing { dismiss() }
        }
        .onChange(of: showPostTripInspection) { _, isShowing in
            if !isShowing {
                if postTripInspectionCompleted {
                    viewModel.endTrip()
                    dismiss()
                }
                postTripInspectionCompleted = false
            }
        }
    }

    // MARK: - Bottom Sticky Button
    @ViewBuilder
    private var bottomStickyButton: some View {
        let buttonContent = VStack(spacing: 10) {
            if trip.status?.lowercased() == "scheduled" {
                Button {
                    if viewModel.assignedVehicle != nil {
                        preTripInspectionCompleted = false
                        showPreTripInspection = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill").font(.system(size: 14, weight: .bold))
                        Text(viewModel.assignedVehicle == nil ? "Waiting for Vehicle" : "Start Trip")
                            .font(.headline.weight(.bold))
                    }
                }
                .buttonStyle(.fmsPrimary)
                .disabled(viewModel.assignedVehicle == nil)

                if trip.endLat != nil && trip.endLng != nil { navigateButton }

            } else if trip.status?.lowercased() == "active" {
                Button {
                    if viewModel.assignedVehicle != nil {
                        postTripInspectionCompleted = false
                        showPostTripInspection = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "flag.checkered").font(.system(size: 14, weight: .bold))
                        Text(viewModel.assignedVehicle == nil ? "Missing Vehicle" : "End Trip")
                            .font(.headline.weight(.bold))
                    }
                }
                .buttonStyle(.fmsPrimary)
                .disabled(viewModel.assignedVehicle == nil)

                Button {
                    showIssueReport = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.bubble.fill").font(.system(size: 14, weight: .semibold))
                        Text("Report Issue").font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(FMSTheme.amber)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background { FMSTheme.amber.opacity(0.12).cornerRadius(14) }
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(FMSTheme.amber.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
            } else {
                Button(action: {}) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                        Text("Trip Completed")
                    }
                }
                .buttonStyle(.fmsPrimary)
                .disabled(true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)

        buttonContent
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask(LinearGradient(
                        gradient: Gradient(colors: [.black, .black, .black, .clear]),
                        startPoint: .bottom, endPoint: .top
                    ))
                    .ignoresSafeArea(edges: .bottom)
            )
    }

    private var statsSection: some View {
        HStack(spacing: 12) {
            TripStatCard(
                iconName: "point.topleft.down.curvedto.point.bottomright.up",
                title: "DISTANCE",
                value: trip.distanceKm.map { String(format: "%.0f km", $0) } ?? "--"
            )
            TripStatCard(
                iconName: "clock",
                title: "DURATION",
                value: (trip.actualDurationMin ?? trip.estimatedDurationMin)?.formattedDuration ?? "--"
            )
            TripStatCard(
                iconName: "123.rectangle",
                title: "STOPS",
                value: "\(activeStops.count) Stops"
            )
        }
    }

    @ViewBuilder
    private var itinerarySection: some View {
        if !activeStops.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Trip Itinerary")
                    .font(.title3.weight(.bold))
                    .foregroundColor(FMSTheme.textPrimary)
                    .padding(.horizontal, 4)

                VStack(spacing: 0) {
                    ForEach(Array(activeStops.enumerated()), id: \.element.id) { index, stop in
                        ItineraryRow(
                            sequenceNumber: index + 1,
                            title: stop.title,
                            address: stop.address,
                            expectedTime: stop.expectedTime,
                            stopType: stop.stopType,
                            isLast: index == activeStops.count - 1
                        )
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(FMSTheme.cardBackground)
                        .shadow(color: FMSTheme.shadowLarge, radius: 6, x: 0, y: 3)
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(FMSTheme.borderLight, lineWidth: 0.5))
                )
            }
        }
    }

    // MARK: - Assigned Vehicle Card
    @ViewBuilder
    private var assignedVehicleCard: some View {
        if let vehicle = tripVehicle ?? viewModel.assignedVehicle {
            HStack(spacing: 16) {
                ZStack {
                    if #available(iOS 26, *) {
                        RoundedRectangle(cornerRadius: 12)
                            .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(FMSTheme.pillBackground)
                    }
                    Image(systemName: "box.truck.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(FMSTheme.amberDark)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text("ASSIGNED VEHICLE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(FMSTheme.textTertiary)
                        .kerning(0.5)
                    Text("\(vehicle.manufacturer ?? "Unknown") \(vehicle.model ?? "")".trimmingCharacters(in: .whitespaces))
                        .font(.title3.weight(.bold))
                        .foregroundColor(FMSTheme.textPrimary)
                        .lineLimit(1)
                    Text(vehicle.plateNumber)
                        .font(.system(.caption, design: .monospaced).bold())
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(FMSTheme.alertYellow)
                        .foregroundColor(.black)
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.2), lineWidth: 1))
                }

                Spacer(minLength: 0)

                if let status = vehicle.status {
                    Text(status.capitalized)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(FMSTheme.statusColor(for: status).opacity(0.12))
                        .foregroundColor(FMSTheme.statusColor(for: status))
                        .cornerRadius(6)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(FMSTheme.cardBackground)
                    .shadow(color: FMSTheme.shadowLarge, radius: 6, x: 0, y: 3)
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(FMSTheme.borderLight, lineWidth: 0.5))
            )
        }
    }

    // MARK: - Trip Info Card
    private var tripInfoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Trip Information")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)
            infoRow(label: "Order #", value: orderNumber ?? String(trip.id.prefix(8)).uppercased())
            infoRow(label: "Status", value: trip.statusLabel, valueColor: FMSTheme.statusColor(for: trip.status ?? ""))
            if let start = trip.startTime { infoRow(label: "Start Time", value: formatDateTime(start)) }
            if let end   = trip.endTime   { infoRow(label: "End Time",   value: formatDateTime(end))   }
        }
        .padding(16)
        .background(FMSTheme.cardBackground)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(FMSTheme.borderLight, lineWidth: 1))
    }

    // MARK: - Shipment Card
    private var shipmentCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Shipment Details")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)
            if let desc   = trip.shipmentDescription { infoRow(label: "Description", value: desc.capitalized) }
            if let weight = trip.shipmentWeightKg    { infoRow(label: "Weight",      value: String(format: "%.0f kg", weight)) }
            if let count  = trip.shipmentPackageCount { infoRow(label: "Packages",   value: "\(count)") }
            if trip.fragile == true {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 12)).foregroundStyle(FMSTheme.alertOrange)
                    Text("Fragile").font(.system(size: 13, weight: .semibold)).foregroundStyle(FMSTheme.alertOrange)
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(FMSTheme.alertOrange.opacity(0.12))
                .cornerRadius(8)
            }
            if let instructions = trip.specialInstructions, !instructions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Special Instructions").font(.system(size: 12, weight: .semibold)).foregroundStyle(FMSTheme.textTertiary)
                    Text(instructions).font(.system(size: 14)).foregroundStyle(FMSTheme.textPrimary)
                }
            }
        }
        .padding(16)
        .background(FMSTheme.cardBackground)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(FMSTheme.borderLight, lineWidth: 1))
    }

    // MARK: - Helpers
    private func infoRow(label: String, value: String, valueColor: Color = FMSTheme.textPrimary) -> some View {
        HStack {
            Text(label).font(.system(size: 13, weight: .medium)).foregroundStyle(FMSTheme.textSecondary)
            Spacer()
            Text(value).font(.system(size: 14, weight: .semibold)).foregroundStyle(valueColor)
        }
    }

    private var navigateButton: some View {
        Button { openAppleMaps() } label: {
            HStack(spacing: 8) {
                Image(systemName: "map.fill").font(.system(size: 14, weight: .semibold))
                Text("Navigate").font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(FMSTheme.amber)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background { FMSTheme.amber.opacity(0.12).cornerRadius(14) }
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(FMSTheme.amber.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Apple Maps (multi-stop)
    private func openAppleMaps() {
        var coords: [(lat: Double, lng: Double, name: String)] = []
        if let lat = trip.startLat, let lng = trip.startLng { coords.append((lat, lng, trip.startName ?? "Origin")) }
        for wp in orderWaypoints { coords.append((wp.lat, wp.lng, wp.name)) }
        if let lat = trip.endLat, let lng = trip.endLng { coords.append((lat, lng, trip.endName ?? "Destination")) }
        guard coords.count >= 2 else { return }

        var items: [URLQueryItem] = [URLQueryItem(name: "saddr", value: "\(coords[0].lat),\(coords[0].lng)")]
        for coord in coords.dropFirst() { items.append(URLQueryItem(name: "daddr", value: "\(coord.lat),\(coord.lng)")) }
        items.append(URLQueryItem(name: "dirflg", value: "d"))

        var components = URLComponents()
        components.scheme = "maps"; components.host = ""; components.queryItems = items

        guard let url = components.url ?? {
            var fb = URLComponents()
            fb.scheme = "https"; fb.host = "maps.apple.com"; fb.queryItems = items
            return fb.url
        }() else { return }
        openURL(url)
    }

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d MMM, h:mm a"; return f
    }()

    private func formatDateTime(_ date: Date) -> String { Self.dateTimeFormatter.string(from: date) }

    // MARK: - Fetch vehicle, order info & waypoints
    private func fetchTripVehicle() async {
        if let vehicleId = trip.vehicleId {
            do {
                let vehicles: [Vehicle] = try await SupabaseService.shared.client
                    .from("vehicles").select().eq("id", value: vehicleId).execute().value
                await MainActor.run { tripVehicle = vehicles.first }
            } catch {
                print("Failed to fetch vehicle for trip: \(error)")
                // Surface to user so they know the vehicle card may be empty
                await MainActor.run {
                    fetchError = "Could not load vehicle details: \(error.localizedDescription)"
                }
            }
        }

        if let orderId = trip.orderId {
            do {
                let rows: [Order] = try await SupabaseService.shared.client
                    .from("orders").select("order_number, waypoints").eq("id", value: orderId).execute().value
                if let order = rows.first {
                    await MainActor.run {
                        orderNumber    = order.orderNumber
                        orderWaypoints = order.waypoints ?? []
                    }
                }
            } catch {
                print("Failed to fetch order info: \(error)")
                // Append to existing message if vehicle also failed, otherwise set fresh
                await MainActor.run {
                    let msg = "Could not load order details: \(error.localizedDescription)"
                    fetchError = fetchError.map { "\($0)\n\(msg)" } ?? msg
                }
            }
        }
    }
}
