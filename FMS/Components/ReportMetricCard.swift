import SwiftUI

public struct ReportMetricCard<ExpandedContent: View>: View {
    public let icon: String
    public let title: String
    public let value: String
    public let subtitle: String?
    public let isExpanded: Bool
    public let expandedContent: () -> ExpandedContent
    
    public init(
        icon: String,
        title: String,
        value: String,
        subtitle: String? = nil,
        isExpanded: Bool = false,
        @ViewBuilder expandedContent: @escaping () -> ExpandedContent = { EmptyView() }
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.isExpanded = isExpanded
        self.expandedContent = expandedContent
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
            
            if isExpanded {
                Divider()
                    .padding(.vertical, 4)
                
                expandedContent()
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
                .stroke(isExpanded ? FMSTheme.amber.opacity(0.5) : FMSTheme.borderLight, lineWidth: isExpanded ? 2 : 1)
        )
    }
}

public extension ReportMetricCard where ExpandedContent == EmptyView {
    init(icon: String, title: String, value: String, subtitle: String? = nil) {
        self.icon = icon
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.isExpanded = false
        self.expandedContent = { EmptyView() }
    }
}
