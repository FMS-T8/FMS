import SwiftUI

public struct ReportMetricCard: View {
    public let icon: String
    public let title: String
    public let value: String
    public let subtitle: String?
    
    public init(icon: String, title: String, value: String, subtitle: String? = nil) {
        self.icon = icon
        self.title = title
        self.value = value
        self.subtitle = subtitle
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                // Colored icon background
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(FMSTheme.amber.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(FMSTheme.amber)
                }
                
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FMSTheme.textSecondary)
                    .lineLimit(1)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(FMSTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundStyle(FMSTheme.textTertiary)
                        .lineLimit(1)
                }
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 100)
        .padding(16)
        .background(FMSTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(FMSTheme.borderLight, lineWidth: 1)
        )
    }
}
