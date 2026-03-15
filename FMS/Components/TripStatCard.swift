//
//  TripStatCard.swift
//  FMS
//
//  Created by NJ on 12/03/26.
//

import SwiftUI

public struct TripStatCard: View {
    public let iconName: String
    public let title: String
    public let value: String
    
    public init(iconName: String, title: String, value: String) {
        self.iconName = iconName
        self.title = title
        self.value = value
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(FMSTheme.symbolColor)
            
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundColor(FMSTheme.textSecondary)
                .textCase(.uppercase)
            
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundColor(FMSTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(FMSTheme.cardBackground)
                .shadow(color: FMSTheme.shadowSmall, radius: 2, x: 0, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(FMSTheme.borderLight, lineWidth: 0.5)
                )
        )
    }
}
