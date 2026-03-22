import SwiftUI

struct BreakReminderBottomSheet: View {
    let level: BreakReminderLevel
    let drivingTime: String
    let onStartBreak: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            handle

            HStack(spacing: 12) {
                iconView

                VStack(alignment: .leading, spacing: 4) {
                    Text(titleText)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(FMSTheme.textPrimary)

                    Text(subtitleText)
                        .font(.system(size: 13))
                        .foregroundStyle(FMSTheme.textSecondary)
                }

                Spacer()
            }

            drivingTimePill

            HStack(spacing: 12) {
                Button(action: onDismiss) {
                    Text("Dismiss")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FMSTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(FMSTheme.pillBackground)
                        .cornerRadius(12)
                }

                Button(action: onStartBreak) {
                    HStack(spacing: 6) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Start Break")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(FMSTheme.obsidian)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(FMSTheme.amber)
                    .cornerRadius(12)
                }
            }
        }
        .padding(20)
        .background(FMSTheme.cardBackground)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(accentColor.opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: FMSTheme.shadowLarge, radius: 16, y: -4)
        .padding(.horizontal, 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Subviews

    private var handle: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(FMSTheme.borderLight)
            .frame(width: 40, height: 4)
    }

    private var iconView: some View {
        Image(systemName: level == .critical ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
            .font(.system(size: 24))
            .foregroundStyle(accentColor)
            .frame(width: 44, height: 44)
            .background(accentColor.opacity(0.12))
            .cornerRadius(12)
    }

    private var drivingTimePill: some View {
        HStack(spacing: 6) {
            Image(systemName: "steering.wheel")
                .font(.system(size: 13))
            Text("Continuous driving: \(drivingTime)")
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(accentColor)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(accentColor.opacity(0.08))
        .cornerRadius(10)
    }

    // MARK: - Computed

    private var accentColor: Color {
        switch level {
        case .none, .gentle: return FMSTheme.alertAmber
        case .warning: return FMSTheme.alertOrange
        case .critical: return FMSTheme.alertRed
        }
    }

    private var titleText: String {
        level == .critical ? "Take a Break Now" : "Rest Break Required"
    }

    private var subtitleText: String {
        level == .critical
            ? "You have exceeded the safe continuous driving limit. Please pull over at the next safe spot."
            : "You've been driving for an extended period. Taking a break helps maintain road safety."
    }
}
