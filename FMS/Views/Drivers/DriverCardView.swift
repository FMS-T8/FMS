import SwiftUI

// MARK: - DriverCardView

/// Reusable card component for the Driver Directory list.
///
/// Displays driver summary: avatar, name, employee ID, vehicle, status badge,
/// shift progress via `ProgressView`, and phone/message quick-action buttons.
/// Designed to be wrapped in a `NavigationLink`.
struct DriverCardView: View {

    let driver: DriverDisplayItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            topRow
            vehicleRow
            shiftProgressSection
            actionButtons
        }
        .padding(16)
        .background(FMSTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Top Row

    private var topRow: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarCircle(initials: driver.avatarInitials, color: avatarColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(driver.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FMSTheme.textPrimary)
                Text("ID: \(driver.employeeID)")
                    .font(.system(size: 13))
                    .foregroundStyle(FMSTheme.textSecondary)
            }
            Spacer(minLength: 4)
            StatusBadge(status: driver.availabilityStatus)
        }
    }

    // MARK: - Vehicle Row

    private var vehicleRow: some View {
        Group {
            if let vName = driver.vehicleDisplayName, let plate = driver.plateNumber {
                HStack(spacing: 6) {
                    Image(systemName: "truck.box.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(FMSTheme.textTertiary)
                    Text("\(vName) · \(plate)")
                        .font(.system(size: 12))
                        .foregroundStyle(FMSTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - Shift Progress

    private var shiftProgressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("SHIFT PROGRESS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(FMSTheme.textTertiary)
                Spacer()
                Text(driver.shiftProgressLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FMSTheme.textSecondary)
            }
            ProgressView(value: driver.shiftProgress)
                .tint(FMSTheme.amber)
        }
    }

    // MARK: - Quick Actions

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Spacer()
            Button {
                // TODO: Initiate phone call
            } label: {
                Image(systemName: "phone.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(FMSTheme.amber)
                    .frame(width: 36, height: 36)
                    .background(FMSTheme.amber.opacity(0.15))
                    .clipShape(Circle())
            }
            Button {
                // TODO: Open message
            } label: {
                Image(systemName: "message.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(FMSTheme.amber)
                    .frame(width: 36, height: 36)
                    .background(FMSTheme.amber.opacity(0.15))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Helpers

    private var avatarColor: Color {
        switch driver.availabilityStatus {
        case .available: return FMSTheme.alertGreen
        case .onTrip:    return FMSTheme.amber
        case .offDuty:   return FMSTheme.textTertiary
        }
    }
}

// MARK: - Shared Sub-components

/// A small circle with two-letter initials.
struct AvatarCircle: View {
    let initials: String
    let color: Color
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
            Text(initials)
                .font(.system(size: size * 0.33, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

/// Color-coded status badge pill.
struct StatusBadge: View {
    let status: DriverAvailabilityStatus

    var body: some View {
        Text("● \(status.displayLabel.uppercased())")
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .clipShape(Capsule())
    }

    private var foregroundColor: Color {
        switch status {
        case .available: return FMSTheme.alertGreen
        case .onTrip:    return FMSTheme.amber
        case .offDuty:   return FMSTheme.textTertiary
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(0.15)
    }
}
