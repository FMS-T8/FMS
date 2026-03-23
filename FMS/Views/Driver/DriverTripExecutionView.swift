import SwiftUI
import MapKit
import CoreLocation

public struct DriverTripExecutionView: View {
    public let trip: Trip
    public let extraStops: [TripStop]

    private let onStartTrip: ((Date) -> Void)?
    private let onEndTrip: ((Date) -> Void)?

    @Environment(\.dismiss) private var dismiss
    var locationManager: LocationManager
    @State private var viewModel: TripExecutionViewModel

    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var showEndTripAlert = false
    @State private var selectedFocus: FocusPoint = .pickup

    private enum FocusPoint: String, CaseIterable {
        case pickup
        case destination

        var title: String {
            switch self {
            case .pickup:
                return "Pickup"
            case .destination:
                return "Destination"
            }
        }
    }

    public init(
        trip: Trip,
        locationManager: LocationManager,
        extraStops: [TripStop] = [],
        onStartTrip: ((Date) -> Void)? = nil,
        onEndTrip: ((Date) -> Void)? = nil
    ) {
        self.trip = trip
        self.locationManager = locationManager
        self.extraStops = extraStops
        self.onStartTrip = onStartTrip
        self.onEndTrip = onEndTrip

        let pickup: CLLocationCoordinate2D? = if let lat = trip.startLat, let lng = trip.startLng {
            CLLocationCoordinate2D(latitude: lat, longitude: lng)
        } else {
            nil
        }
        
        let destination: CLLocationCoordinate2D? = if let lat = trip.endLat, let lng = trip.endLng {
            CLLocationCoordinate2D(latitude: lat, longitude: lng)
        } else {
            nil
        }

        self._viewModel = State(
            initialValue: TripExecutionViewModel(
                tripId: trip.id,
                pickupCoordinate: pickup,
                destinationCoordinate: destination
            )
        )
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                mapSection
                statusSection
                actionSection
                syncPreviewSection
            }
            .padding(16)
        }
        .background(FMSTheme.backgroundPrimary)
        .navigationTitle("Trip Execution")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(FMSTheme.textPrimary)
                }
            }
        }
        .onAppear {
            viewModel.attachLocationManager(locationManager)
            viewModel.configureInitialState(status: trip.status, startTime: trip.startTime, endTime: trip.endTime)
            viewModel.requestPermissionsAndTracking()
            centerMap(on: selectedFocus)
        }
        .onDisappear {
            viewModel.stopTracking()
        }
        .onChange(of: selectedFocus) { _, focus in
            centerMap(on: focus)
        }
        .alert("End Trip?", isPresented: $showEndTripAlert) {
            Button("Cancel", role: .cancel) {}
            Button("End Trip", role: .destructive) {
                viewModel.endTrip()
                if let endedAt = viewModel.endTime {
                    onEndTrip?(endedAt)
                }
            }
        } message: {
            Text("This will mark the trip as delivered and stop location tracking.")
        }
    }

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Live Geofence")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(FMSTheme.textPrimary)
                Spacer()
                Picker("Map Focus", selection: $selectedFocus) {
                    ForEach(FocusPoint.allCases, id: \.self) { point in
                        Text(point.title).tag(point)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }

            Map(position: $mapPosition) {
                if let pickup = pickupCoordinate {
                    Annotation("Pickup", coordinate: pickup) {
                        marker(icon: "shippingbox.fill", title: "Pickup")
                    }
                    MapCircle(center: pickup, radius: viewModel.geofenceRadius)
                        .foregroundStyle(FMSTheme.amber.opacity(0.14))
                }

                if let destination = destinationCoordinate {
                    Annotation("Destination", coordinate: destination) {
                        marker(icon: "flag.checkered", title: "Drop")
                    }
                    MapCircle(center: destination, radius: viewModel.geofenceRadius)
                        .foregroundStyle(FMSTheme.alertGreen.opacity(0.12))
                }

                ForEach(Array(extraStops.enumerated()), id: \.element.id) { index, stop in
                    if let lat = stop.lat, let lng = stop.lng {
                        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                        Annotation("Stop \(index + 1)", coordinate: coordinate) {
                            marker(icon: "point.bottomleft.forward.to.point.topright.scurvepath", title: "Stop \(index + 1)")
                        }
                        MapCircle(center: coordinate, radius: viewModel.geofenceRadius)
                            .foregroundStyle(FMSTheme.alertOrange.opacity(0.1))
                    }
                }

                if let current = locationManager.currentLocation?.coordinate {
                    Annotation("Current", coordinate: current) {
                        ZStack {
                            Circle()
                                .fill(FMSTheme.obsidian)
                                .frame(width: 18, height: 18)
                            Circle()
                                .stroke(FMSTheme.amber, lineWidth: 3)
                                .frame(width: 26, height: 26)
                        }
                    }
                }
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(FMSTheme.borderLight, lineWidth: 1)
            )
            .padding(.horizontal, 16)

            Text("Geofence radius: \(Int(viewModel.geofenceRadius))m")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FMSTheme.textSecondary)
        }
        .padding(16)
        .background(FMSTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current Phase: \(viewModel.currentPhase.title)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)

            Text(permissionStatusText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(locationManager.isPermissionDenied ? FMSTheme.alertRed : FMSTheme.textSecondary)

            if let pickupDistance = viewModel.pickupDistanceMeters {
                Text("Pickup Distance: \(Int(pickupDistance))m")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(viewModel.insidePickupGeofence ? FMSTheme.alertGreen : FMSTheme.textSecondary)
            }

            if let destinationDistance = viewModel.destinationDistanceMeters {
                Text("Destination Distance: \(Int(destinationDistance))m")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(viewModel.insideDestinationGeofence ? FMSTheme.alertGreen : FMSTheme.textSecondary)
            }

            if let start = viewModel.startTime {
                Text("Start Time: \(dateFormatter.string(from: start))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FMSTheme.textSecondary)
            }

            if let end = viewModel.endTime {
                Text("End Time: \(dateFormatter.string(from: end))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FMSTheme.textSecondary)
            }

            if trip.startLat == nil || trip.startLng == nil || trip.endLat == nil || trip.endLng == nil {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Trip coordinates missing. Geofencing disabled.")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(FMSTheme.alertOrange)
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(FMSTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var actionSection: some View {
        VStack(spacing: 10) {
            if !viewModel.hasStartedTrip {
                Button {
                    viewModel.startTrip()
                    if let startedAt = viewModel.startTime {
                        onStartTrip?(startedAt)
                    }
                } label: {
                    Label("Start Trip", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.fmsPrimary)
                .disabled(!viewModel.canStartTrip)

                if !viewModel.insidePickupGeofence {
                    Text("Move within 1000m of pickup to start")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(FMSTheme.alertOrange)
                        .padding(.top, 4)
                }
            } else if !viewModel.hasEndedTrip {
                if viewModel.insideDestinationGeofence {
                    Button {
                        showEndTripAlert = true
                    } label: {
                        Label("End Trip", systemImage: "flag.checkered")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.fmsPrimary)
                    .disabled(!viewModel.canEndTrip)
                } else {
                    Button {
                        viewModel.isBreakActive ? viewModel.resumeTrip() : viewModel.takeBreak()
                    } label: {
                        Label(
                            viewModel.isBreakActive ? "Resume" : "Take Break",
                            systemImage: viewModel.isBreakActive ? "play.circle.fill" : "pause.circle.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.fmsPrimary)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Trip Completed")
                }
                .font(.headline)
                .foregroundColor(FMSTheme.alertGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(FMSTheme.alertGreen.opacity(0.12))
                .cornerRadius(14)
            }
        }
    }

    private var syncPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location Queue (Supabase-ready)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)

            if viewModel.samplesReadyForSync.isEmpty {
                Text("No samples yet. Tracking starts once trip starts.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FMSTheme.textSecondary)
            } else {
                ForEach(viewModel.samplesReadyForSync.suffix(3)) { sample in
                    Text("\(sample.timestamp.formatted(date: .omitted, time: .standard)) • \(sample.latitude), \(sample.longitude)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(FMSTheme.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
        .background(FMSTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var pickupCoordinate: CLLocationCoordinate2D? {
        guard let lat = trip.startLat, let lng = trip.startLng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    private var destinationCoordinate: CLLocationCoordinate2D? {
        guard let lat = trip.endLat, let lng = trip.endLng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    private var permissionStatusText: String {
        if locationManager.isPermissionDenied {
            return "Location permission denied. Enable Always access to use trip actions."
        }
        if locationManager.isAuthorizedForTrip {
            return "Always location access active."
        }
        return "Waiting for Always location permission."
    }

    private func centerMap(on focus: FocusPoint) {
        switch focus {
        case .pickup:
            if let pickupCoordinate {
                mapPosition = .region(
                    MKCoordinateRegion(
                        center: pickupCoordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
                    )
                )
            }
        case .destination:
            if let destinationCoordinate {
                mapPosition = .region(
                    MKCoordinateRegion(
                        center: destinationCoordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
                    )
                )
            }
        }
    }

    private func marker(icon: String, title: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(FMSTheme.obsidian)
                .frame(width: 28, height: 28)
                .background(FMSTheme.amber, in: Circle())
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, h:mm a"
        return formatter
    }
}
