//
//  MapCard.swift
//  FMS
//
//  Created by NJ on 12/03/26.
//

import SwiftUI
import MapKit

public struct MockStop: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let address: String
    public let expectedTime: String
    public let stopType: StopType
    public let coordinate: CLLocationCoordinate2D
    
    public init(title: String, address: String, expectedTime: String, stopType: StopType, coordinate: CLLocationCoordinate2D) {
        self.title = title
        self.address = address
        self.expectedTime = expectedTime
        self.stopType = stopType
        self.coordinate = coordinate
    }
    
    public static func == (lhs: MockStop, rhs: MockStop) -> Bool {
        lhs.id == rhs.id
    }
}

public struct MapCard: View {
    public let stops: [MockStop]
    @State private var routes: [MKRoute] = []
    @State private var position: MapCameraPosition = .automatic
    
    public init(stops: [MockStop]) {
        self.stops = stops
    }
    
    // Create a bounding box based on the stops
    private var mapCameraPosition: MapCameraPosition {
        guard !stops.isEmpty else {
            return .automatic
        }
        
        // Calculate the bounding region plus padding
        let latitudes = stops.map { $0.coordinate.latitude }
        let longitudes = stops.map { $0.coordinate.longitude }
        
        let maxLat = latitudes.max()!
        let minLat = latitudes.min()!
        let maxLon = longitudes.max()!
        let minLon = longitudes.min()!
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.6 + 0.05,
            longitudeDelta: (maxLon - minLon) * 1.6 + 0.05
        )
        
        return .region(MKCoordinateRegion(center: center, span: span))
    }
    
    public var body: some View {
        Map(position: $position) {
            // Draw the calculated driving routes connecting the stops
            ForEach(Array(routes.enumerated()), id: \.offset) { _, route in
                MapPolyline(route.polyline)
                    .stroke(FMSTheme.amber, lineWidth: 5)
            }
            
            // Render annotations for each stop
            ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                Annotation(stop.title, coordinate: stop.coordinate) {
                    ZStack {
                        Circle()
                            .fill(index == 0 || index == 1 ? FMSTheme.amber : FMSTheme.cardBackground)
                            .frame(width: 28, height: 28)
                            .shadow(radius: 2, y: 1)
                        
                        Text("\(index + 1)")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(index == 0 || index == 1 ? .black : FMSTheme.textPrimary)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .mapControls {
            MapCompass()
            MapScaleView()
            MapPitchToggle()
            MapUserLocationButton()
        }
        .onAppear {
            position = mapCameraPosition
        }
        .task(id: stops) {
            await fetchRoutes()
        }
    }
    
    private func fetchRoutes() async {
        guard stops.count > 1 else { return }
        
        var calculatedRoutes: [MKRoute] = []
        
        for i in 0..<(stops.count - 1) {
            let source = MKPlacemark(coordinate: stops[i].coordinate)
            let destination = MKPlacemark(coordinate: stops[i+1].coordinate)
            
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: source)
            request.destination = MKMapItem(placemark: destination)
            request.transportType = .automobile
            
            let directions = MKDirections(request: request)
            if let response = try? await directions.calculate(), let route = response.routes.first {
                calculatedRoutes.append(route)
            }
        }
        
        // Ensure UI update happens on the main thread
        await MainActor.run {
            self.routes = calculatedRoutes
        }
    }
}
