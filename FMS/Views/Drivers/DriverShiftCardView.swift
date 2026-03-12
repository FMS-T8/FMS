import SwiftUI

// MARK: - DriverShiftCardView

/// Reusable card for the Shifts tab.
///
/// Displays driver name, vehicle ID, shift start/end, status,
/// and a `ProgressView` for shift progress.
/// Designed to be wrapped in a `NavigationLink`.
struct DriverShiftCardView: View {

    let shift: ShiftDisplayItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            shiftTimingRow
            progressSection
        }
        .padding(16)
        .background(FMSTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarCircle(
                initials: shift.avatarInitials,
                color: statusColor,
                size: 42
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(shift.driverName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FMSTheme.textPrimary)
                if let plate = shift.plateNumber {
                    Text("Vehicle: \(plate)")
                        .font(.system(size: 12))
                        .foregroundStyle(FMSTheme.textSecondary)
                }
            }

            Spacer(minLength: 4)

            Text(shift.statusLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(statusColor)
        }
    }

    // MARK: - Timing

    private var shiftTimingRow: some View {
        HStack {
            Label(formattedTime(shift.shiftStart), systemImage: "clock")
                .font(.system(size: 12))
                .foregroundStyle(FMSTheme.textSecondary)
            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundStyle(FMSTheme.textTertiary)
            Text(formattedTime(shift.shiftEnd))
                .font(.system(size: 12))
                .foregroundStyle(FMSTheme.textSecondary)
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("SHIFT PROGRESS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(FMSTheme.textTertiary)
                Spacer()
                Text(shift.progressLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FMSTheme.textSecondary)
            }
            ProgressView(value: shift.progress)
                .tint(progressTint)
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch shift.status {
        case "on_duty":     return FMSTheme.alertGreen
        case "break":       return FMSTheme.amber
        case "not_started": return FMSTheme.textTertiary
        default:            return FMSTheme.textSecondary
        }
    }

    private var progressTint: Color {
        shift.status == "not_started" ? FMSTheme.textTertiary : FMSTheme.amber
    }

    private func formattedTime(_ date: Date?) -> String {
        guard let d = date else { return "--" }
        let f = DateFormatter()
        f.dateFormat = "hh:mm a"
        return f.string(from: d)
    }
}
