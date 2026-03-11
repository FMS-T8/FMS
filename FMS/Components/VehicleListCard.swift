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
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(UIColor.secondarySystemFill))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "box.truck.fill")
                    .font(.system(size: 20))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
            
            // Center: Vehicle Details
            VStack(alignment: .leading, spacing: 2) {
                let manufacturer = vehicle.manufacturer ?? ""
                let model = vehicle.model ?? ""
                let fullName = "\(manufacturer) \(model)".trimmingCharacters(in: .whitespaces)
                
                Text(fullName.isEmpty ? "Unknown Vehicle" : fullName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(vehicle.plateNumber)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer(minLength: 8)
            
            if let status = vehicle.status?.lowercased() {
                Text(status.capitalized)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor(for: status).opacity(0.15))
                    .foregroundColor(statusColor(for: status))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(colorScheme == .dark ? Color(UIColor.secondarySystemGroupedBackground) : .white)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private func statusColor(for status: String) -> Color {
        switch status {
        case "active":
            return .green
        case "inactive":
            return .gray
        default:
            return .primary
        }
    }
}
