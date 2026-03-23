import SwiftUI

struct BreakReminderBannerView: View {
    let level: BreakReminderLevel
    let drivingTime: String
    let onDismiss: () -> Void
    let onStartBreak: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(accentColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(titleText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(FMSTheme.textPrimary)

                Text(subtitleText)
                    .font(.system(size: 12))
                    .foregroundStyle(FMSTheme.textSecondary)
            }

            Spacer()

            Button(action: onStartBreak) {
                Text("Take Break")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(FMSTheme.obsidian)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(FMSTheme.amber)
                    .cornerRadius(8)
            }
            .accessibilityLabel("Take Break — driving for \(drivingTime)")

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(FMSTheme.textTertiary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(FMSTheme.cardBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(accentColor.opacity(0.4), lineWidth: 1.5)
        )
        .shadow(color: FMSTheme.shadowSmall, radius: 4, y: 2)
        .padding(.horizontal, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var iconName: String {
        switch level {
        case .none: return "clock"
        case .gentle: return "clock.badge.exclamationmark"
        case .warning: return "exclamationmark.triangle"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }

    private var accentColor: Color {
        switch level {
        case .none: return FMSTheme.textSecondary
        case .gentle: return FMSTheme.alertAmber
        case .warning: return FMSTheme.alertOrange
        case .critical: return FMSTheme.alertRed
        }
    }

    private var titleText: String {
        switch level {
        case .none: return ""
        case .gentle: return "Rest Break Recommended"
        case .warning: return "Mandatory Rest Break"
        case .critical: return "CRITICAL: Take a Break Now"
        }
    }

    private var subtitleText: String {
        switch level {
        case .none: return ""
        case .gentle: return "You've been driving for \(drivingTime). A rest break is recommended."
        case .warning: return "\(drivingTime) driving. Please take a mandatory rest break."
        case .critical: return "\(drivingTime) without break. Pull over safely and rest."
        }
    }
}
