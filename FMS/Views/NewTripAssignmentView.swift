//
//  NewTripAssignmentView.swift
//  FMS
//
//  Created by NJ on 12/03/26.
//

import SwiftUI
import CoreLocation

// Note: To show interactivity, let's make this view dynamic!
public struct NewTripAssignmentView: View {
    let trip: Trip
    @Bindable var viewModel: DriverDashboardViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showIssueReport = false
    @State private var showPreTripInspection = false
    @State private var showPostTripInspection = false
    @State private var preTripInspectionCompleted = false
    @State private var postTripInspectionCompleted = false
    
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
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Map
                    MapCard(stops: activeStops)
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
                    
                    // Stats
                    statsSection
                    
                    // Itinerary
                    itinerarySection
                    
                    // Trip details embedded
                    tripInfoCard
                    if trip.shipmentDescription != nil {
                        shipmentCard
                    }
                    
                    // Bottom padding to ensure last item clears the active buttons
                    Spacer().frame(height: 40)
                }
                .padding(16)
            }
            .background(FMSTheme.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("New Trip Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.bold))
                            .foregroundColor(FMSTheme.textPrimary)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomStickyButton
            }
            .sheet(isPresented: $showIssueReport) {
                IssueReportView(viewModel: viewModel)
            }
            .fullScreenCover(isPresented: $showPreTripInspection) {
                InspectionChecklistView(
                    type: .preTrip,
                    vehicleId: viewModel.assignedVehicle?.id ?? "VH-001",
                    driverId: viewModel.driver.id,
                    onCompletion: {
                        preTripInspectionCompleted = true
                    }
                )
            }
            .fullScreenCover(isPresented: $showPostTripInspection) {
                InspectionChecklistView(
                    type: .postTrip,
                    vehicleId: viewModel.assignedVehicle?.id ?? "VH-001",
                    driverId: viewModel.driver.id,
                    onCompletion: {
                        postTripInspectionCompleted = true
                    }
                )
            }
            .onChange(of: showPreTripInspection) { _, isShowing in
                if !isShowing {
                    if preTripInspectionCompleted {
                        viewModel.startTrip(trip)
                        dismiss()
                    }
                    preTripInspectionCompleted = false
                }
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
    }
    
    @ViewBuilder
    private var bottomStickyButton: some View {
        let buttonContent = VStack(spacing: 10) {
            if trip.status?.lowercased() == "scheduled" {
                Button {
                    preTripInspectionCompleted = false
                    showPreTripInspection = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Start Trip")
                            .font(.headline.weight(.bold))
                    }
                }
                .buttonStyle(.fmsPrimary)
            } else if trip.status?.lowercased() == "active" {
                Button {
                    postTripInspectionCompleted = false
                    showPostTripInspection = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 14, weight: .bold))
                        Text("End Trip")
                            .font(.headline.weight(.bold))
                    }
                }
                .buttonStyle(.fmsPrimary)

                Button {
                    showIssueReport = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.bubble.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Report Issue")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(FMSTheme.amber)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(FMSTheme.amber.opacity(0.12))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(FMSTheme.amber.opacity(0.3), lineWidth: 1)
                    )
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
        .padding(.bottom, 8) // Accommodates safe area
        buttonContent
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask(
                        LinearGradient(gradient: Gradient(colors: [.black, .black, .black, .clear]), startPoint: .bottom, endPoint: .top)
                    )
                    .ignoresSafeArea(edges: .bottom)
            )
    }
    
    // Removed headerSection as it is now natively handled by the NavigationBar/Toolbar
    
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
    
    private var itinerarySection: some View {
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(FMSTheme.borderLight, lineWidth: 0.5)
                    )
            )
        }
    }
    
    // MARK: - Trip Info Card

    private var tripInfoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Trip Information")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)

            infoRow(label: "Trip ID", value: trip.id.uppercased())
            infoRow(label: "Vehicle", value: viewModel.assignedVehicle?.plateNumber ?? "—")
            infoRow(label: "Status", value: trip.statusLabel, valueColor: FMSTheme.statusColor(for: trip.status ?? ""))

            if let start = trip.startTime {
                infoRow(label: "Start Time", value: formatDateTime(start))
            }

            if let end = trip.endTime {
                infoRow(label: "End Time", value: formatDateTime(end))
            }

            if let duration = trip.actualDurationMin ?? trip.estimatedDurationMin {
                let label = trip.actualDurationMin != nil ? "Duration" : "Est. Duration"
                infoRow(label: label, value: duration.formattedDuration)
            }
        }
        .padding(16)
        .background(FMSTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(FMSTheme.borderLight, lineWidth: 1)
        )
    }

    // MARK: - Shipment Card

    private var shipmentCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Shipment Details")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)

            if let desc = trip.shipmentDescription {
                infoRow(label: "Description", value: desc)
            }

            if let weight = trip.shipmentWeightKg {
                infoRow(label: "Weight", value: String(format: "%.0f kg", weight))
            }

            if let count = trip.shipmentPackageCount {
                infoRow(label: "Packages", value: "\(count)")
            }

            if trip.fragile == true {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(FMSTheme.alertOrange)
                    Text("Fragile")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FMSTheme.alertOrange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(FMSTheme.alertOrange.opacity(0.12))
                .cornerRadius(8)
            }

            if let instructions = trip.specialInstructions, !instructions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Special Instructions")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FMSTheme.textTertiary)
                    Text(instructions)
                        .font(.system(size: 14))
                        .foregroundStyle(FMSTheme.textPrimary)
                }
            }
        }
        .padding(16)
        .background(FMSTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(FMSTheme.borderLight, lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func infoRow(label: String, value: String, valueColor: Color = FMSTheme.textPrimary) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(FMSTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(valueColor)
        }
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, h:mm a"
        return formatter.string(from: date)
    }
}
