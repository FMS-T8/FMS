//
//  ItineraryRow.swift
//  FMS
//
//  Created by NJ on 12/03/26.
//

import SwiftUI

public enum StopType: String {
    case pickup = "PICKUP"
    case dropOff = "DROP-OFF"
    
    var backgroundColor: Color {
        switch self {
        case .pickup: return Color(red: 235/255, green: 250/255, blue: 240/255) // Light green
        case .dropOff: return Color(red: 235/255, green: 240/255, blue: 255/255) // Light blue
        }
    }
    
    var textColor: Color {
        switch self {
        case .pickup: return Color(red: 40/255, green: 160/255, blue: 80/255) // Dark green
        case .dropOff: return Color(red: 60/255, green: 100/255, blue: 220/255) // Dark blue
        }
    }
}

public struct ItineraryRow: View {
    public let sequenceNumber: Int
    public let title: String
    public let address: String
    public let expectedTime: String
    public let stopType: StopType
    public let isLast: Bool
    
    public init(sequenceNumber: Int, title: String, address: String, expectedTime: String, stopType: StopType, isLast: Bool = false) {
        self.sequenceNumber = sequenceNumber
        self.title = title
        self.address = address
        self.expectedTime = expectedTime
        self.stopType = stopType
        self.isLast = isLast
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Indicator Column
            VStack(spacing: 0) {
                // Circle
                ZStack {
                    Circle()
                        .fill(sequenceNumber == 1 || sequenceNumber == 2 ? FMSTheme.amber.opacity(0.2) : Color.gray.opacity(0.1))
                        .frame(width: 28, height: 28)
                    
                    Text("\(sequenceNumber)")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(sequenceNumber == 1 || sequenceNumber == 2 ? FMSTheme.amberDark : FMSTheme.textTertiary)
                }
                
                // Line connecting down
                if !isLast {
                    Rectangle()
                        .fill(FMSTheme.borderLight)
                        .frame(width: 2)
                        .padding(.vertical, 4)
                } else {
                    Spacer(minLength: 0)
                }
            }
            .frame(width: 28)
            
            // Content Column
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(FMSTheme.textPrimary)
                
                Text(address)
                    .font(.subheadline)
                    .foregroundColor(FMSTheme.textSecondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(expectedTime)
                }
                .font(.subheadline)
                .foregroundColor(FMSTheme.textSecondary)
                .padding(.top, 4)
            }
            .padding(.bottom, isLast ? 0 : 20)
            
            Spacer(minLength: 0)
            
            // Trailing Pill
            Text(stopType.rawValue)
                .font(.caption.weight(.bold))
                .foregroundColor(stopType.textColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(stopType.backgroundColor)
                )
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
