//
//  VehicleListCard.swift
//  FMS
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
                    HStack(spacing: 6) {
                        Text(vehicle.plateNumber)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(FMSTheme.textPrimary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(FMSTheme.backgroundPrimary)
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusDotColor)
                            .frame(width: 8, height: 8)
                        Text(statusLabel)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(statusTextColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusPillBackground)
                    .cornerRadius(10)
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
                        // Tracking flow not wired yet.
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
                    .buttonStyle(.plain)
                    .disabled(true)
                    .opacity(0.6)
                    .accessibilityHint("Tracking is unavailable.")
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

    private var statusLabel: String {
        switch normalizedStatus {
        case "active": return "On Trip"
        case "maintenance": return "Maintenance"
        case "inactive": return "In Yard"
        default:
            let trimmed = vehicle.status?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let raw = trimmed.isEmpty ? "Unknown" : trimmed
            let readable = raw
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
            return readable.capitalized
        }
    }
    
    private var statusPillBackground: Color {
        switch normalizedStatus {
        case "active": return FMSTheme.alertGreen.opacity(0.15)
        case "maintenance": return FMSTheme.alertAmber.opacity(0.2)
        case "inactive": return FMSTheme.textTertiary.opacity(0.15)
        default: return FMSTheme.backgroundPrimary
        }
    }
    
    private var statusTextColor: Color {
        switch normalizedStatus {
        case "active": return FMSTheme.alertGreen
        case "maintenance": return FMSTheme.alertAmber
        case "inactive": return FMSTheme.textSecondary
        default: return FMSTheme.textSecondary
        }
    }
    
    private var statusDotColor: Color {
        switch normalizedStatus {
        case "active": return FMSTheme.alertGreen
        case "maintenance": return FMSTheme.alertAmber
        case "inactive": return FMSTheme.textSecondary
        default: return FMSTheme.statusColor(for: vehicle.status ?? "")
        }
    }

    private var normalizedStatus: String {
        VehicleStatus.normalize(vehicle.status ?? "")
    }
    
    
}
