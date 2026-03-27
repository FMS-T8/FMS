import SwiftUI

/// A single row showing a completed (or ongoing) break in the history list.
struct BreakHistoryRow: View {
    let breakLog: BreakLog

    private var typeIcon: String {
        BreakType(rawValue: breakLog.breakType ?? "other")?.icon ?? "ellipsis.circle.fill"
    }
    private var typeName: String {
        BreakType(rawValue: breakLog.breakType ?? "Other")?.rawValue ?? "Break"
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icon badge
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(FMSTheme.amber.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: typeIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(FMSTheme.amber)
            }

            // Labels
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(typeName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FMSTheme.textPrimary)

                    if breakLog.isOngoing {
                        Text("ONGOING")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(FMSTheme.alertRed)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(FMSTheme.alertRed.opacity(0.12))
                            .cornerRadius(4)
                    }
                }

                Text(timeRangeText)
                    .font(.system(size: 12))
                    .foregroundStyle(FMSTheme.textSecondary)

                if let notes = breakLog.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 12))
                        .foregroundStyle(FMSTheme.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Duration badge
            Text(breakLog.formattedDuration)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FMSTheme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(FMSTheme.pillBackground)
                .cornerRadius(8)
        }
        .padding(12)
        .background(FMSTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(FMSTheme.borderLight, lineWidth: 1)
        )
    }

    private var timeRangeText: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        let start = breakLog.startTime.map { f.string(from: $0) } ?? "—"
        if let end = breakLog.endTime {
            return "\(start) – \(f.string(from: end))"
        }
        return "Started at \(start)"
    }
}
