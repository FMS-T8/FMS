import SwiftUI
import MapKit

/// Full-screen historical trip replay view for Fleet Managers.
public struct TripReplayView: View {
    let trip: Trip

    @State private var vm = TripReplayViewModel()
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var showEventTimeline = false
    @Environment(\.dismiss) private var dismiss

    public init(trip: Trip) {
        self.trip = trip
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            // ── Full-screen map ──────────────────────────────────────────
            mapLayer
                .ignoresSafeArea()

            // ── Loading / Error overlay ──────────────────────────────────
            if vm.isLoading {
                loadingOverlay
            } else if let error = vm.errorMessage {
                errorOverlay(error)
            } else if !vm.hasData {
                noDataOverlay
            }

            // ── Event timeline sheet (incidents + breaks) ────────────────
            if showEventTimeline && vm.hasData {
                eventTimelinePanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // ── Playback controls ────────────────────────────────────────
            if vm.hasData && !vm.isLoading {
                VStack(spacing: 0) {
                    // Timeline toggle button
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showEventTimeline.toggle()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: showEventTimeline
                                      ? "chevron.down.circle.fill"
                                      : "list.bullet.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(showEventTimeline ? "Hide Events" : "Events (\(vm.incidents.count + vm.breakLogs.count))")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(FMSTheme.obsidian)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(FMSTheme.amber)
                            .clipShape(Capsule())
                            .shadow(color: FMSTheme.amber.opacity(0.4), radius: 8, y: 3)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 16)
                        .padding(.bottom, 10)
                    }

                    TripReplayControlsView(vm: vm, trip: trip)
                }
            }
        }
        .navigationTitle("Trip Replay")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                recenterButton
            }
        }
        .task {
            await vm.load(trip: trip)
            fitCameraToPath()
        }
        .onDisappear {
            vm.stopLivePolling()
            vm.pause()
        }
    }

    // MARK: - Map Layer

        private var mapLayer: some View {
            Map(position: $mapCameraPosition) {
                // Ghost path (full route, dimmed)
                if vm.allCoordinates.count > 1 {
                    // Wrapper forces clean memory allocation based on count
                    ForEach([vm.allCoordinates], id: \.count) { coords in
                        MapPolyline(coordinates: coords)
                            .stroke(FMSTheme.textTertiary.opacity(0.35), lineWidth: 3)
                    }
                }

                // Played-back path (amber)
                if vm.playedCoordinates.count > 1 {
                    // Wrapper forces clean memory allocation during playback updates
                    ForEach([vm.playedCoordinates], id: \.count) { coords in
                        MapPolyline(coordinates: coords)
                            .stroke(FMSTheme.amber, lineWidth: 4)
                    }
                }

                // Start marker
                if let first = vm.allCoordinates.first {
                    Annotation("Start", coordinate: first, anchor: .bottom) {
                        routeEndpointMarker(color: .blue, icon: "flag.fill")
                    }
                }

                // End marker
                if let last = vm.allCoordinates.last, vm.allCoordinates.count > 1 {
                    Annotation("End", coordinate: last, anchor: .bottom) {
                        routeEndpointMarker(color: FMSTheme.alertGreen, icon: "flag.checkered")
                    }
                }

                // Incident pins
                ForEach(vm.incidents) { incident in
                    if let lat = incident.lat, let lng = incident.lng {
                        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                        Annotation("", coordinate: coord, anchor: .center) {
                            incidentPin(incident)
                        }
                    }
                }

                // Break pins
                ForEach(vm.breakLogs) { breakLog in
                    if let lat = breakLog.lat, let lng = breakLog.lng {
                        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                        Annotation("Break", coordinate: coord, anchor: .center) {
                            breakPin(breakLog)
                        }
                    }
                }

                // Current position (animated truck dot)
                if let current = vm.currentPoint,
                   let lat = current.lat, let lng = current.lng {
                    let coord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                    Annotation("Vehicle", coordinate: coord, anchor: .center) {
                        currentPositionMarker
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
        }
    // MARK: - Map Annotations

    private var currentPositionMarker: some View {
        let heading = vm.currentPoint?.heading ?? 0
        let status = positionStatus
        return ZStack {
            Circle()
                .stroke(status.color, lineWidth: 3)
                .frame(width: 32, height: 32)
            Circle()
                .fill(FMSTheme.amber)
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(Color.white, lineWidth: 3))
                .shadow(color: FMSTheme.amber.opacity(0.6), radius: 6)
            Image(systemName: "location.north.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(FMSTheme.obsidian)
                .rotationEffect(Angle(degrees: heading))
        }
        .accessibilityLabel("Vehicle status: \(status.label)")
    }

    private var positionStatus: (label: String, color: Color) {
        guard let kph = vm.currentSpeedKph else {
            return ("Unknown", FMSTheme.textTertiary)
        }
        if kph < 0.5 { return ("Stopped", FMSTheme.textSecondary) }
        if kph < 5 { return ("Idle", FMSTheme.alertAmber) }
        switch vm.speedCategory {
        case .normal:
            return ("Moving", FMSTheme.alertGreen)
        case .fast:
            return ("Moving", FMSTheme.alertAmber)
        case .speeding:
            return ("Moving", FMSTheme.alertRed)
        }
    }

    private func routeEndpointMarker(color: Color, icon: String) -> some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 28, height: 28)
                .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                .shadow(radius: 4)
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private func incidentPin(_ incident: Incident) -> some View {
        ZStack {
            Circle()
                .fill(FMSTheme.alertRed)
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(radius: 3)
            Image(systemName: incident.severity == "hard_brake"
                  ? "exclamationmark.triangle.fill"
                  : "burst.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private func breakPin(_ breakLog: BreakLog) -> some View {
        ZStack {
            Circle()
                .fill(FMSTheme.textSecondary)
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(radius: 3)
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
        }
    }

    // MARK: - Event Timeline Panel

    private enum TimelineEvent: Identifiable {
        case incident(Incident)
        case breakLog(BreakLog)

        var id: String {
            switch self {
            case .incident(let incident):
                return "incident-\(incident.id)"
            case .breakLog(let breakLog):
                return "break-\(breakLog.id)"
            }
        }

        var date: Date? {
            switch self {
            case .incident(let incident):
                return incident.createdAt
            case .breakLog(let breakLog):
                return breakLog.startTime
            }
        }
    }

    private var timelineEvents: [TimelineEvent] {
        let events = vm.incidents.map { TimelineEvent.incident($0) }
            + vm.breakLogs.map { TimelineEvent.breakLog($0) }
        return events.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
    }

    private var eventTimelinePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(FMSTheme.borderLight)
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 8)

            Text("Events on This Trip")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(FMSTheme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            ScrollView {
                LazyVStack(spacing: 8) {
                    if timelineEvents.isEmpty {
                        Text("No events recorded for this trip.")
                            .font(.system(size: 13))
                            .foregroundColor(FMSTheme.textTertiary)
                            .padding(.vertical, 20)
                            .frame(maxWidth: .infinity)
                    } else {
                        ForEach(timelineEvents) { event in
                            switch event {
                            case .incident(let incident):
                                eventRow(
                                    icon: incident.severity == "hard_brake"
                                        ? "exclamationmark.triangle.fill"
                                        : "burst.fill",
                                    iconColor: FMSTheme.alertRed,
                                    title: incident.severity == "hard_brake" ? "Hard Brake" : "Possible Crash",
                                    subtitle: formatEventDate(incident.createdAt),
                                    detail: incidentSpeedDetail(incident)
                                )
                            case .breakLog(let breakLog):
                                eventRow(
                                    icon: "cup.and.heat.waves.fill",
                                    iconColor: FMSTheme.textSecondary,
                                    title: "Driver Break",
                                    subtitle: formatEventDate(breakLog.startTime),
                                    detail: breakLog.formattedDuration
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .frame(maxHeight: 220)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 12, y: -2)
        // Sit above the controls panel (approx 210 pt tall)
        .padding(.bottom, 260)
        .padding(.horizontal, 12)
    }

    private func eventRow(icon: String, iconColor: Color, title: String, subtitle: String, detail: String?) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(FMSTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(FMSTheme.textTertiary)
            }
            Spacer()
            if let detail {
                Text(detail)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(FMSTheme.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(FMSTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: FMSTheme.shadowSmall, radius: 3, y: 2)
    }

    // MARK: - Overlays

    private var loadingOverlay: some View {
        VStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: FMSTheme.amber))
                .scaleEffect(1.3)
            Text("Loading replay data…")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(FMSTheme.textSecondary)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 8)
    }

    private func errorOverlay(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(FMSTheme.alertOrange)
            Text("Failed to load replay")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(FMSTheme.textPrimary)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(FMSTheme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await vm.load(trip: trip) }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(FMSTheme.obsidian)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(FMSTheme.amber)
            .clipShape(Capsule())
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 8)
    }

    private var noDataOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(FMSTheme.textTertiary)
            Text("No GPS Data")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(FMSTheme.textPrimary)
            Text("No location points were recorded for this trip.")
                .font(.system(size: 12))
                .foregroundColor(FMSTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 8)
    }

    // MARK: - Toolbar Actions

    private var recenterButton: some View {
        Button {
            fitCameraToPath()
        } label: {
            Image(systemName: "scope")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(FMSTheme.textSecondary)
        }
    }

    // MARK: - Helpers

    private func fitCameraToPath() {
        let coords = vm.allCoordinates
        guard coords.count > 1 else {
            if let first = coords.first {
                mapCameraPosition = .camera(
                    MapCamera(centerCoordinate: first, distance: 8000)
                )
            }
            return
        }
        let lats = coords.map(\.latitude)
        let lngs = coords.map(\.longitude)
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLng = lngs.min()!, maxLng = lngs.max()!
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta:  (maxLat - minLat) * 1.4,
            longitudeDelta: (maxLng - minLng) * 1.4
        )
        mapCameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }

    private func formatEventDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter.string(from: date)
    }

    private func incidentSpeedDetail(_ incident: Incident) -> String? {
        if let before = incident.speedBefore {
            return String(format: "%.0f km/h", before)
        }
        return nil
    }
}
