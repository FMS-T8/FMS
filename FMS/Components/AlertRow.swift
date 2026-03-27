import SwiftUI

public enum AlertType {
    case warning   // Amber
    case info      // Yellow
    case critical  // Red
    
    var color: Color {
        switch self {
        case .warning: return FMSTheme.alertAmber
        case .info: return FMSTheme.alertYellow
        case .critical: return FMSTheme.alertRed
        }
    }
    
    var icon: String {
        switch self {
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "clock.fill"
        case .critical: return "location.slash.fill"
        }
    }
}

public struct AlertRow: View {
    public let title: String
    public let subtitle: String
    public let timeAgo: String
    public let type: AlertType
    public let vehiclePlate: String?
    
    public init(title: String, subtitle: String, timeAgo: String, type: AlertType, vehiclePlate: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.timeAgo = timeAgo
        self.type = type
        self.vehiclePlate = vehiclePlate
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            // Left color indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(type.color)
                .frame(width: 4)
                .padding(.vertical, 12)
            
            HStack(spacing: 12) {
                // Icon
                Image(systemName: type.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(type.color)
                    .frame(width: 24)
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(FMSTheme.textPrimary)
                    
                    if let plate = vehiclePlate {
                            Text("\(plate)")
                            .font(.system(size: 10, weight: .black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(type.color.opacity(0.12))
                            .foregroundColor(type.color)
                            .clipShape(Capsule())
                    }
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(FMSTheme.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Time
                Text(timeAgo)
                    .font(.system(size: 12))
                    .foregroundColor(FMSTheme.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(FMSTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(FMSTheme.borderLight, lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        AlertRow(
            title: "Tyre pressure warning",
            subtitle: "Truck #402 reported low pressure in rear-left tyre.",
            timeAgo: "12m ago",
            type: .warning
        )
        
        AlertRow(
            title: "Driver break scheduled",
            subtitle: "Driver David R. is reaching mandatory rest limit in 15 mins.",
            timeAgo: "45m ago",
            type: .info
        )
        
        AlertRow(
            title: "Geofence deviation",
            subtitle: "Truck #109 exited the designated route area in North District.",
            timeAgo: "1h ago",
            type: .critical
        )
    }
    .padding()
    .background(FMSTheme.backgroundPrimary)
}
