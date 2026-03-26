//
//  LiveVehicleDashboardView.swift
//  FMS
//

import Foundation
import SwiftUI

public struct LiveVehicleDashboardView: View {
    @State private var viewModel = LiveVehicleViewModel()
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .top) {
            FMSTheme.backgroundPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Navigation Header
                HStack(spacing: 16) {
                    // Back Button
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(FMSTheme.cardBackground)
                                .frame(width: 48, height: 48)
                            
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(FMSTheme.textPrimary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Active Vehicles")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(FMSTheme.textPrimary)
                        
                        Text("\(viewModel.filteredTrips.count) Currently Active")
                            .font(.system(size: 14))
                            .foregroundColor(FMSTheme.textSecondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if viewModel.isLoading {
                            ProgressView()
                                .padding(.top, 50)
                                .tint(FMSTheme.amber)
                        } else if viewModel.filteredTrips.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "truck.box")
                                    .font(.system(size: 40))
                                    .foregroundColor(FMSTheme.textTertiary)
                                Text("No active vehicles found")
                                    .font(.headline)
                                    .foregroundColor(FMSTheme.textSecondary)
                            }
                            .padding(.top, 100)
                        } else {
                            ForEach(viewModel.filteredTrips) { info in
                                NavigationLink {
                                    TrackingShipmentView(trip: info.trip, vehicle: info.vehicle)
                                } label: {
                                    LiveTripCard(
                                        plateNumber: info.vehicle.plateNumber,
                                        origin: info.trip.startName ?? "Mysore",
                                        destination: info.trip.endName ?? "Bengaluru",
                                        completionPercentage: info.completionPercentage
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            while !Task.isCancelled {
                await viewModel.fetchVehicles()
                try? await Task.sleep(nanoseconds: 70_000_000_000)
            }
        }
    }
}
