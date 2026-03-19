import SwiftUI

/// A small badge showing month-over-month cost variance as a percentage.
public struct VarianceBadge: View {
    public let percent: Double?

    public init(percent: Double?) {
        self.percent = percent
    }

    public var body: some View {
        if let pct = percent {
            let isPositive = pct >= 0
            HStack(spacing: 2) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 9, weight: .bold))
                Text(String(format: "%+.1f%%", pct))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isPositive ? FMSTheme.alertRed : FMSTheme.alertGreen)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                (isPositive ? FMSTheme.alertRed : FMSTheme.alertGreen).opacity(0.12),
                in: Capsule()
            )
        }
    }
}
