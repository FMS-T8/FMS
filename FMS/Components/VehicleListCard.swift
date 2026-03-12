//
//  VehicleListCard.swift
//  FMS
//
//  Created by Anish on 11/03/26.
//

import Foundation
import SwiftUI

struct VehicleListCard: View {
    let vehicle: Vehicle
    
    var body: some View {
        HStack(spacing: 0) {
            // Main Content
            VStack(alignment: .leading, spacing: 14) {
                // Header Row (Plate Pill)
                HStack(alignment: .top) {
                    // Plate Number Pill
                    HStack(spacing: 6) {
                        Circle()
                            .fill(FMSTheme.statusColor(for: vehicle.status ?? ""))
                            .frame(width: 8, height: 8)
                        
                        Text(vehicle.plateNumber)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(FMSTheme.textPrimary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(FMSTheme.backgroundPrimary)
                    .cornerRadius(8)
                    
                    Spacer()
                }
                
                // Details Rows
                VStack(alignment: .leading, spacing: 8) {
                    // Row 1: Vehicle Model & Plate
                    HStack(spacing: 6) {
                        Image(systemName: "box.truck.fill")
                            .font(.system(size: 12))
                            .foregroundColor(FMSTheme.textTertiary)
                        
                        Text("\(vehicle.manufacturer ?? "Unknown") \(vehicle.model ?? "")")
                            .font(.system(size: 14))
                            .foregroundColor(FMSTheme.textSecondary)
                    }
                    
                    // Row 2: Carrying Capacity
                    HStack(spacing: 6) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 12))
                            .foregroundColor(FMSTheme.textTertiary)
                        
                        let capacityStr = vehicle.carryingCapacity != nil ? "\(Int(vehicle.carryingCapacity!)) kg" : "Capacity Unknown"
                        Text(capacityStr)
                            .font(.system(size: 14))
                            .foregroundColor(FMSTheme.textSecondary)
                    }
                }
                

                
                // Action Buttons
                HStack(spacing: 12) {
                    Button {
                        // Track Action
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 14, weight: .bold))
                                .rotationEffect(.degrees(45))
                                .offset(x: -2, y: 2)
                            Text("Track")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(FMSTheme.obsidian)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(FMSTheme.amber)
                        .cornerRadius(10)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.all, 16)
        }
        .background(FMSTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .compositingGroup()
        .shadow(color: FMSTheme.shadowSmall, radius: 6, x: 0, y: 4)
    }
    
    // MARK: - Helpers
    
    private var vehicleName: String {
        let manufacturer = vehicle.manufacturer ?? ""
        let model = vehicle.model ?? ""
        let fullName = "\(manufacturer) \(model)".trimmingCharacters(in: .whitespaces)
        return fullName.isEmpty ? "Unknown Vehicle" : fullName
    }
    
    
}
