import SwiftUI

public struct DriverStatCard: View {
    public let icon: String
    public let value: String
    public let label: String

    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(FMSTheme.amber)

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(FMSTheme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(FMSTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(FMSTheme.borderLight, lineWidth: 1)
        )
    }
}
