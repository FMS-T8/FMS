import SwiftUI

public struct FMSRoleCard: View {
    public let title: String
    public let systemImage: String
    public let description: String
    public let isSelected: Bool
    public let action: () -> Void
    
    public init(title: String, systemImage: String, description: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
        self.isSelected = isSelected
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: systemImage)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(isSelected ? FMSTheme.obsidian : FMSTheme.amber)
                    .frame(width: 60)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2.weight(.bold))
                        .foregroundColor(isSelected ? FMSTheme.obsidian : .primary)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(isSelected ? FMSTheme.obsidian.opacity(0.8) : .secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? FMSTheme.amber : FMSTheme.obsidian)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(FMSTheme.amber, lineWidth: isSelected ? 0 : 2)
            )
        }
        .buttonStyle(.plain)
    }
}
