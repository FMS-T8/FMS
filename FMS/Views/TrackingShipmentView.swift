//
//  TrackingShipmentView.swift
//  FMS
//
//  Created by Anish on 12/03/26.
//

import Foundation
import SwiftUI
import MapKit

public struct TrackingShipmentView: View {
    @State private var viewModel = TrackingShipmentViewModel()
    
    @State private var sheetHeight: CGFloat = 420
    @State private var previousDragTranslation: CGFloat = 0
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    @Environment(\.dismiss) private var dismiss
    
    private let minSheetHeight: CGFloat = 420
    private let maxSheetHeight: CGFloat = 520
    
    // MARK: - Local theme properties have been removed since FMSTheme is now globally adaptive.

    public init(trip: Trip? = nil, vehicle: Vehicle? = nil) {
        self._viewModel = State(initialValue: TrackingShipmentViewModel(trip: trip, vehicle: vehicle))
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // MARK: - Map Layer
            Map(position: $cameraPosition) {
                if let current = viewModel.currentCoordinate {
                    Annotation("Current", coordinate: current) {
                        ZStack {
                            Circle()
                                .fill(FMSTheme.amber)
                                .frame(width: 52, height: 52)
                                .shadow(color: FMSTheme.amber.opacity(0.4), radius: 10, y: 4)
                            
                            Image(systemName: "box.truck.fill")
                                .font(.system(size: 24))
                                .foregroundColor(FMSTheme.obsidian)
                        }
                    }
                }
                
                if let dest = viewModel.destinationCoordinate {
                    Annotation("Destination", coordinate: dest) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 38))
                            .foregroundColor(FMSTheme.textPrimary)
                            .background(Circle().fill(FMSTheme.cardBackground).frame(width: 14, height: 14))
                    }
                }
            }
            .safeAreaPadding(.bottom, sheetHeight + 20)
            
            // MARK: - Smooth Top Gradient Fade Layer
            VStack {
                LinearGradient(
                    colors: [
                        FMSTheme.backgroundPrimary,
                        FMSTheme.backgroundPrimary.opacity(0.9),
                        FMSTheme.backgroundPrimary.opacity(0.4),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 140) // Covers the safe area and smoothly fades into the map
                .ignoresSafeArea(edges: .top)
                
                Spacer()
            }
            .allowsHitTesting(false) // Ensures you can still pan the map underneath the fade
            
            // MARK: - Bottom Sheet Layer
            bottomSheetContent
        }
        .ignoresSafeArea(.all, edges: .bottom)
        
        // MARK: - Navigation Bar Configuration
        .navigationTitle("Tracking Shipment")
        .navigationBarTitleDisplayMode(.inline)
        // Hide the harsh flat background to let our custom gradient shine
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task {
            while !Task.isCancelled {
                await viewModel.fetchDetails()
                try? await Task.sleep(nanoseconds: 70_000_000_000)
            }
        }
    }
    
    // MARK: - Bottom Sheet Components
    
    private var bottomSheetContent: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(FMSTheme.borderLight)
                .frame(width: 48, height: 6)
                .padding(.vertical, 16)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    driverProfileSection
                    tripDetailsSection
                    timelineSection
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 60)
            }
        }
        .frame(height: sheetHeight)
        .frame(maxWidth: .infinity)
        .background(FMSTheme.backgroundPrimary)
        .fmsGlassEffect(cornerRadius: 32)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: FMSTheme.shadowLarge, radius: 15, x: 0, y: -5)
        .gesture(
            DragGesture()
                .onChanged { value in
                    let delta = value.translation.height - previousDragTranslation
                    sheetHeight = min(max(sheetHeight - delta, minSheetHeight), maxSheetHeight)
                    previousDragTranslation = value.translation.height
                }
                .onEnded { _ in
                    previousDragTranslation = 0
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if sheetHeight > (maxSheetHeight + minSheetHeight) / 2 {
                            sheetHeight = maxSheetHeight
                        } else {
                            sheetHeight = minSheetHeight
                        }
                    }
                }
        )
    }
    
    private var driverProfileSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(FMSTheme.borderLight.opacity(0.5))
                    .frame(width: 56, height: 56)
                
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 56, height: 56)
                    .foregroundColor(FMSTheme.textTertiary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.driver?.name ?? "Unknown Driver")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(FMSTheme.textPrimary)
                
                Text("Delivery Partner")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(FMSTheme.textSecondary)
            }
            
            Spacer()
            
            Button(action: { /* Call Action */ }) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 20))
                    .foregroundColor(FMSTheme.obsidian)
                    .frame(width: 48, height: 48)
                    .background(FMSTheme.amber)
                    .clipShape(Circle())
            }
        }
    }
    
    private var tripDetailsSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Trip Number")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(FMSTheme.textSecondary)
                Text(viewModel.formattedTripId)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(FMSTheme.textPrimary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 6) {
                Text("Estimated Date")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(FMSTheme.textSecondary)
                Text(viewModel.formattedEstimatedDate)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(FMSTheme.textPrimary)
            }
        }
        .padding(20)
        .background(FMSTheme.cardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(FMSTheme.borderLight.opacity(0.5), lineWidth: 1)
        )
    }
    
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Shipment Details")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(FMSTheme.textPrimary)
                .padding(.bottom, 20)
            
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 0) {
                    Circle()
                        .fill(FMSTheme.amber)
                        .frame(width: 14, height: 14)
                        .background(Circle().stroke(FMSTheme.amber.opacity(0.3), lineWidth: 6))
                    
                    Rectangle()
                        .fill(FMSTheme.borderLight)
                        .frame(width: 2, height: 50)
                    
                    Circle()
                        .fill(FMSTheme.alertRed)
                        .frame(width: 14, height: 14)
                }
                .padding(.top, 4)
                
                VStack(alignment: .leading, spacing: 30) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Origin")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(FMSTheme.textSecondary)
                        Text(viewModel.trip?.startName ?? "Unknown Origin")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(FMSTheme.textPrimary)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Deliver To")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(FMSTheme.textSecondary)
                        Text(viewModel.trip?.endName ?? "Unknown Destination")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(FMSTheme.textPrimary)
                    }
                }
            }
        }
    }
}
