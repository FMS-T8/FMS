import SwiftUI
import MapKit
import CoreLocation

public struct GeofenceMapPoint: Identifiable {
    public enum Kind {
        case pickup
        case stop(index: Int)
        case destination

        public var title: String {
            switch self {
            case .pickup:
                return "Pickup"
            case let .stop(index):
                return "Stop \(index + 1)"
            case .destination:
                return "Destination"
            }
        }

        public var iconName: String {
            switch self {
            case .pickup:
                return "shippingbox.fill"
            case .stop:
                return "point.bottomleft.forward.to.point.topright.scurvepath"
            case .destination:
                return "flag.checkered"
            }
        }
    }

    public let id: String
    public let kind: Kind
    public let name: String
    public let coordinate: CLLocationCoordinate2D

    public init(id: String = UUID().uuidString, kind: Kind, name: String, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.kind = kind
        self.name = name
        self.coordinate = coordinate
    }
}

public struct GeofenceSelectorMap: View {
    public let points: [GeofenceMapPoint]
    public let radiusMeters: CLLocationDistance

    @State private var selectedPointID: String?
    @State private var cameraPosition: MapCameraPosition = .automatic

    public init(points: [GeofenceMapPoint], radiusMeters: CLLocationDistance = 400) {
        self.points = points
        self.radiusMeters = radiusMeters
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Geofence Selector")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)
                .padding(.horizontal, 16)

            if points.isEmpty {
                Text("Add pickup, stops, and destination coordinates to preview geofences.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(FMSTheme.textSecondary)
                    .padding(.horizontal, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(points) { point in
                            Button {
                                selectedPointID = point.id
                                centerCamera(on: point.coordinate)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: point.kind.iconName)
                                    Text(point.kind.title)
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(isSelected(point) ? FMSTheme.obsidian : FMSTheme.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(isSelected(point) ? FMSTheme.amber : FMSTheme.pillBackground)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Map(position: $cameraPosition) {
                    ForEach(points) { point in
                        Annotation(point.kind.title, coordinate: point.coordinate) {
                            VStack(spacing: 4) {
                                Image(systemName: point.kind.iconName)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(FMSTheme.obsidian)
                                    .frame(width: 28, height: 28)
                                    .background(FMSTheme.amber, in: Circle())

                                Text(point.kind.title)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(FMSTheme.textPrimary)
                            }
                        }

                        MapCircle(center: point.coordinate, radius: radiusMeters)
                            .foregroundStyle(FMSTheme.amber.opacity(isSelected(point) ? 0.22 : 0.12))
                    }
                }
                .frame(height: 230)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(FMSTheme.borderLight, lineWidth: 1)
                )
                .padding(.horizontal, 16)
            }
        }
        .onAppear {
            guard let first = points.first else { return }
            if selectedPointID == nil {
                selectedPointID = first.id
            }
            centerCamera(on: selectedPoint?.coordinate ?? first.coordinate)
        }
        .onChange(of: points.count) { _, _ in
            guard let first = points.first else { return }
            if selectedPoint == nil {
                selectedPointID = first.id
            }
            centerCamera(on: selectedPoint?.coordinate ?? first.coordinate)
        }
    }

    private var selectedPoint: GeofenceMapPoint? {
        points.first { $0.id == selectedPointID }
    }

    private func isSelected(_ point: GeofenceMapPoint) -> Bool {
        selectedPointID == point.id
    }

    private func centerCamera(on coordinate: CLLocationCoordinate2D) {
        cameraPosition = .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
            )
        )
    }
}
