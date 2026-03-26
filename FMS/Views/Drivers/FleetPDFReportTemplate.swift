//
//  FleetPDFReportTemplate.swift
//  FMS
//
//  Created by Anish on 27/03/26.
//

import Foundation
import SwiftUI
import Charts

public struct FleetPDFReportTemplate: View {
    let viewModel: FleetReportViewModel
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            
            Divider()
            
            summaryGrid
            
            if !viewModel.tripsData.isEmpty {
                Divider()
                topTripsChart
            }
            
            if !viewModel.fuelData.isEmpty || !viewModel.incidentsData.isEmpty {
                Divider()
                HStack(alignment: .top, spacing: 32) {
                    if !viewModel.fuelData.isEmpty {
                        recentFuelLogs
                    }
                    if !viewModel.incidentsData.isEmpty {
                        recentIncidents
                    }
                }
            }
            
            Spacer(minLength: 0)
            
            footer
        }
        .padding(40)
        .frame(width: 595.2, height: 841.8) // A4 Size
        .background(Color.white) // Use absolute white for PDF
        // Override the theme just for the PDF so text is readable on white
        .environment(\.colorScheme, .light)
    }
    
    // MARK: - Sections
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Fleet Performance Report")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.black)
                
                Text(viewModel.dateLabel)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                
                if let vId = viewModel.selectedVehicleId, let v = viewModel.availableVehicles.first(where: { $0.id == vId }) {
                    Text("Filtered by Vehicle: \(v.plateNumber)")
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                }
                
                if let dId = viewModel.selectedDriverId, let d = viewModel.availableDrivers.first(where: { $0.id == dId }) {
                    Text("Filtered by Driver: \(d.name)")
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                }
            }
            Spacer()
            // Try to use an SF symbol as a logo for the report
            Image(systemName: "box.truck.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .foregroundColor(Color(hex: "#F6C944")) // Hardcode Amber
        }
    }
    
    private var summaryGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Executive Summary")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.black)
            
            HStack(spacing: 20) {
                pdfStatBox(title: "Total Trips", value: "\(viewModel.totalTrips)", subtitle: "\(viewModel.completedTrips) completed")
                pdfStatBox(title: "Distance", value: "\(Int(viewModel.totalDistanceKm)) km", subtitle: "Total distance")
                pdfStatBox(title: "Fuel Cost", value: "₹\(Int(viewModel.totalFuelCost))", subtitle: "\(String(format: "%.1f", viewModel.totalFuelLiters)) L used")
            }
            
            HStack(spacing: 20) {
                pdfStatBox(title: "Safety Events", value: "\(viewModel.safetyEventCount)", subtitle: "Sensor triggers")
                pdfStatBox(title: "Incidents", value: "\(viewModel.incidentCount)", subtitle: "Reported issues")
                pdfStatBox(title: "Work Orders", value: "\(viewModel.activeMaintenanceCount)", subtitle: "Active maintenance")
            }
        }
    }
    
    private var topTripsChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top Trips by Distance")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.black)
            
            let sortedTrips = viewModel.tripsData
                .filter { ($0.distance_km ?? 0) > 0 }
                .sorted { ($0.distance_km ?? 0) > ($1.distance_km ?? 0) }
                .prefix(5) // Top 5
            
            Chart {
                ForEach(sortedTrips, id: \.id) { trip in
                    BarMark(
                        x: .value("Trip", trip.id.prefix(6).uppercased()),
                        y: .value("Distance (km)", trip.distance_km ?? 0)
                    )
                    .foregroundStyle(Color(hex: "#F6C944"))
                    .annotation(position: .top) {
                        Text("\(Int(trip.distance_km ?? 0))")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 150)
        }
    }
    
    private var recentFuelLogs: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Fuel Logs")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
            
            ForEach(viewModel.fuelData.prefix(5), id: \.id) { fuel in
                VStack(alignment: .leading, spacing: 2) {
                    Text(fuel.fuel_station ?? "Unknown Station")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.black)
                    HStack {
                        Text("\(String(format: "%.1f", fuel.fuel_volume ?? 0)) L")
                        Spacer()
                        Text("₹\(Int(fuel.amount_paid ?? 0))")
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                }
                .padding(.bottom, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var recentIncidents: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Incidents")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
            
            ForEach(viewModel.incidentsData.prefix(5), id: \.id) { incident in
                VStack(alignment: .leading, spacing: 2) {
                    Text(incident.severity?.capitalized ?? "Issue")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.black)
                    Text(incident.created_at?.prefix(10) ?? "")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var footer: some View {
        HStack {
            Text("Generated by Fleet Management System")
                .font(.system(size: 10))
                .foregroundColor(.gray)
            Spacer()
            Text(Date().formatted())
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Helpers
    
    private func pdfStatBox(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.black)
            Text(subtitle)
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.gray)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.95))
        .cornerRadius(8)
    }
}

// Minimal Color extension for the hardcoded hex
fileprivate extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
