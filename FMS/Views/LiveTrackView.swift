//
//  LiveTrackView.swift
//  FMS
//
//  Created by Nikunj Mathur on 22/03/26.
//

import SwiftUI
import MapKit
import Supabase

public struct LiveTrackView: View {
    let order: Order
    let tripId: String

    public init(order: Order, tripId: String) {
        self.order = order
        self.tripId = tripId
    }

    @State private var driverCoordinate: CLLocationCoordinate2D? = nil
    @State private var lastUpdatedAt: Date? = nil
    @State private var isInitialLoad = true
    @State private var routePolylines: [MKRoute] = []
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var pollTimer: Timer? = nil

    @Environment(\.dismiss) private var dismiss

    private let pollInterval: TimeInterval = 5

    private var originCoord: CLLocationCoordinate2D? {
        guard let lat = order.originLat, let lng = order.originLng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
    private var destinationCoord: CLLocationCoordinate2D? {
        guard let lat = order.destinationLat, let lng = order.destinationLng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    public var body: some View {
        ZStack {
            mapLayer

            VStack {
                Spacer()
                statusBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
            }
        }
        .navigationTitle("Live Track")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await calculateRoute()
            await fetchLatestPing()
            isInitialLoad = false
        }
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    // MARK: - Timer Management (robust, not affected by SwiftUI task cancellation)

    private func startTimer() {
        stopTimer()
        print("[LiveTrackView] ⏱️ Starting poll timer for trip \(tripId)")
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { _ in
            Task { @MainActor in
                await fetchLatestPing()
            }
        }
    }

    private func stopTimer() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Map

    private var mapLayer: some View {
        Map(position: $cameraPosition) {
            ForEach(Array(routePolylines.enumerated()), id: \.offset) { _, route in
                MapPolyline(route).stroke(FMSTheme.amber, lineWidth: 4)
            }

            if let origin = originCoord {
                Annotation("Pickup", coordinate: origin) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .shadow(radius: 3)
                }
            }

            if let dest = destinationCoord {
                Annotation("Delivery", coordinate: dest) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .shadow(radius: 3)
                }
            }

            if let coord = driverCoordinate {
                Annotation("Driver", coordinate: coord) {
                    ZStack {
                        Circle()
                            .fill(FMSTheme.amber.opacity(0.25))
                            .frame(width: 44, height: 44)
                        Circle()
                            .fill(FMSTheme.amber)
                            .frame(width: 22, height: 22)
                            .overlay(Circle().stroke(Color.white, lineWidth: 3))
                            .shadow(color: FMSTheme.amber.opacity(0.5), radius: 6)
                        Image(systemName: "truck.box.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(FMSTheme.obsidian)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(driverCoordinate != nil ? Color.green : FMSTheme.textTertiary)
                    .frame(width: 8, height: 8)
                Text(driverCoordinate != nil ? "LIVE" : "No Signal")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(driverCoordinate != nil ? Color.green : FMSTheme.textTertiary)
            }

            Divider().frame(height: 16)

            if let ts = lastUpdatedAt {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundColor(FMSTheme.textSecondary)
                    Text("Updated \(ts, formatter: relativeFormatter)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(FMSTheme.textSecondary)
                }
            } else if isInitialLoad {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Text("No location data yet")
                    .font(.system(size: 12))
                    .foregroundColor(FMSTheme.textTertiary)
            }

            Spacer()

            if let origin = order.originName {
                Text(origin.split(separator: ",").first.map(String.init) ?? origin)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(FMSTheme.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }

    // MARK: - Data Fetching

    @MainActor
    private func fetchLatestPing() async {
        do {
            struct GPSRow: Decodable {
                let lat: Double
                let lng: Double
                let speed: Double?
                let recorded_at: Date
            }

            let rows: [GPSRow] = try await SupabaseService.shared.client
                .from("trip_gps_logs")
                .select("lat, lng, speed, recorded_at")
                .eq("trip_id", value: tripId)
                .order("recorded_at", ascending: false)
                .limit(1)
                .execute()
                .value

            if let latest = rows.first {
                print("[LiveTrackView] 📍 Got ping: lat=\(latest.lat), lng=\(latest.lng)")
                let coord = CLLocationCoordinate2D(latitude: latest.lat, longitude: latest.lng)
                withAnimation(.easeInOut(duration: 0.4)) {
                    self.driverCoordinate = coord
                }
                self.lastUpdatedAt = latest.recorded_at

                if isInitialLoad {
                    cameraPosition = .camera(
                        MapCamera(centerCoordinate: coord, distance: 8000)
                    )
                }
            } else {
                print("[LiveTrackView] No GPS data found for trip \(tripId)")
            }
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == -999 { return }
            print("[LiveTrackView] ❌ Failed to fetch GPS ping: \(error.localizedDescription)")
        }
    }

    // MARK: - Route

    private func calculateRoute() async {
        guard let origin = originCoord, let dest = destinationCoord else { return }
        let request = MKDirections.Request()
        request.source       = MKMapItem(location: CLLocation(latitude: origin.latitude, longitude: origin.longitude), address: nil)
        request.destination  = MKMapItem(location: CLLocation(latitude: dest.latitude, longitude: dest.longitude), address: nil)
        request.transportType = .automobile
        do {
            let response = try await MKDirections(request: request).calculate()
            if let route = response.routes.first {
                await MainActor.run { routePolylines = [route] }
            }
        } catch {
            print("[LiveTrackView] Route calculation failed: \(error)")
        }
    }

    private var relativeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}
