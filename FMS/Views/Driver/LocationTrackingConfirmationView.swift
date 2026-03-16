//
//  LocationTrackingConfirmationView.swift
//  FMS
//
//  Created by NJ on 12/03/26.
//

import SwiftUI
import MapKit

public struct LocationTrackingConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    let trip: Trip
    
    // Simulate real-time tracking visualization
    @State private var isPulsing = false
    
    public init(trip: Trip) {
        self.trip = trip
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            
            // Top Half: Map Tracking Overview
            Map(position: $position) {
                UserAnnotation()
                
                // Active Pulsing Indicator
                if let lat = trip.startLat, let lng = trip.startLng {
                    let startCoord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                    Annotation("Active Start", coordinate: startCoord) {
                        ZStack {
                            Circle()
                                .fill(FMSTheme.statusColor(for: "active").opacity(0.3))
                                .frame(width: isPulsing ? 100 : 20, height: isPulsing ? 100 : 20)
                            
                            Circle()
                                .fill(FMSTheme.statusColor(for: "active"))
                                .frame(width: 20, height: 20)
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .frame(height: UIScreen.main.bounds.height * 0.45)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: FMSTheme.shadowLarge, radius: 16, x: 0, y: 8)
            .padding(.top, 16)
            .padding(.horizontal, 16)
            
            // Bottom Half: Confirmation Typography & Actions
            VStack(spacing: 24) {
                Spacer()
                
                // Icon & Headline
                VStack(spacing: 12) {
                    Image(systemName: "location.viewfinder")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(FMSTheme.statusColor(for: "active"))
                        .symbolEffect(.pulse, options: .repeating)
                    
                    Text("Location Sharing Active")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(FMSTheme.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text("Your device is successfully sharing location coordinates for dispatch safety and accurate routing.")
                        .font(.body)
                        .foregroundStyle(FMSTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                Spacer()
                
                // Proceed Button
                Button {
                    // Completes the flow and returns to parent (which drops them to active dashboard)
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        Text("Proceed to Route")
                            .font(.headline.weight(.bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.fmsPrimary)
                .padding(.horizontal, 24)
                .padding(.bottom, 40) // Safe Area bumper
            }
            .background(FMSTheme.backgroundPrimary)
        }
        .background(FMSTheme.backgroundPrimary.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
            
            // Request user location centering if start coordinates are missing
            if trip.startLat == nil {
                position = .userLocation(fallback: .automatic)
            }
        }
    }
}
