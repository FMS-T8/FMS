import SwiftUI

public struct FMSBanner: View {
    @Environment(BannerManager.self) private var bannerManager
    public init() {}
    
    private func accentColor(for type: BannerType) -> Color {
        switch type {
        case .error: return FMSTheme.alertRed
        case .warning: return FMSTheme.alertOrange
        case .success: return FMSTheme.alertGreen
        }
    }
    
    private func iconName(for type: BannerType) -> String {
        switch type {
        case .error: return "exclamationmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .success: return "checkmark.circle.fill"
        }
    }
    

    
    public var body: some View {
        if let banner = bannerManager.currentBanner {
            let accent = accentColor(for: banner.type)
            
            HStack(spacing: 12) {
                Image(systemName: iconName(for: banner.type))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(accent)
                
                Text(banner.message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(FMSTheme.textPrimary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                Button {
                    bannerManager.dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(FMSTheme.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(FMSTheme.cardBackground)
            .overlay(
                Rectangle()
                    .fill(accent)
                    .frame(width: 4),
                alignment: .leading
            )
            .cornerRadius(12)
            .shadow(color: FMSTheme.shadowMedium, radius: 12, x: 0, y: 4)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .id(banner.id)
        }
    }
}

#Preview("Error Banner") {
    let manager = BannerManager()
    
    ZStack(alignment: .top) {
        Color(red: 247/255, green: 247/255, blue: 249/255).ignoresSafeArea()
        FMSBanner()
    }
    .environment(manager)
    .onAppear {
        manager.show(type: .error, message: "Unable to connect to server. Please check your network.", duration: 60)
    }
}

#Preview("Warning Banner - Dark") {
    let manager = BannerManager()
    
    ZStack(alignment: .top) {
        Color(red: 18/255, green: 18/255, blue: 20/255).ignoresSafeArea()
        FMSBanner()
    }
    .environment(manager)
    .preferredColorScheme(.dark)
    .onAppear {
        manager.show(type: .warning, message: "Sync delayed. Retrying in background...", duration: 60)
    }
}
