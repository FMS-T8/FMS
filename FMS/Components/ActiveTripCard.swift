import SwiftUI

// MARK: - Current Job Card

public struct CurrentJobCard: View {
    public let trip: Trip
    public let vehiclePlate: String?
    public let isActive: Bool
    public let onStartJob: () -> Void
    public let onDetails: () -> Void
    public let onEndTrip: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Amber decorative strip at top
            RoundedRectangle(cornerRadius: 0)
                .fill(
                    LinearGradient(
                        colors: [FMSTheme.amber.opacity(0.3), FMSTheme.amber.opacity(0.08)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 6)

            VStack(alignment: .leading, spacing: 16) {
                // Pickup
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("PICKUP")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.blue)
                            .tracking(0.5)

                        Text(trip.startName ?? "Origin")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(FMSTheme.textPrimary)
                    }
                }

                // Delivery
                HStack(spacing: 10) {
                    Circle()
                        .fill(FMSTheme.alertGreen)
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("DELIVERY")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(FMSTheme.alertGreen)
                            .tracking(0.5)

                        Text(trip.endName ?? "Destination")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(FMSTheme.textPrimary)
                    }
                }

                // Divider
                Rectangle()
                    .fill(FMSTheme.borderLight)
                    .frame(height: 1)

                // Time & Cargo row
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TIME")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(FMSTheme.textTertiary)
                            .tracking(0.5)

                        Text(formattedTime)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FMSTheme.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("CARGO")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(FMSTheme.textTertiary)
                            .tracking(0.5)

                        Text(cargoDescription)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FMSTheme.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Action buttons
                HStack(spacing: 10) {
                    if isActive {
                        Button(action: onEndTrip) {
                            Text("End Trip")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(FMSTheme.obsidian)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(FMSTheme.amber)
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: onStartJob) {
                            Text("Start Job")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(FMSTheme.obsidian)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(FMSTheme.amber)
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: onDetails) {
                        Text("Details")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(FMSTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(FMSTheme.cardBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(FMSTheme.borderLight, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
        }
        .background(FMSTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(FMSTheme.borderLight, lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private var formattedTime: String {
        guard let time = trip.startTime else { return "—" }
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(time) {
            formatter.dateFormat = "'Today,' h:mm a"
        } else if Calendar.current.isDateInTomorrow(time) {
            formatter.dateFormat = "'Tomorrow,' h:mm a"
        } else {
            formatter.dateFormat = "EEE, h:mm a"
        }
        return formatter.string(from: time)
    }

    private var cargoDescription: String {
        var parts: [String] = []
        if let desc = trip.shipmentDescription {
            parts.append(desc)
        }
        if let weight = trip.shipmentWeightKg {
            parts.append("(\(String(format: "%.1f", weight / 1000))t)")
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " ")
    }
}

// MARK: - No Active Trip Card

public struct NoActiveTripCard: View {
    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "map.fill")
                .font(.system(size: 36))
                .foregroundStyle(FMSTheme.amber.opacity(0.6))

            Text("No Active Trip")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)

            Text("Your next trip will appear here")
                .font(.system(size: 14))
                .foregroundStyle(FMSTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(FMSTheme.cardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(FMSTheme.borderLight, style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
        )
    }
}

// MARK: - Upcoming Job Card

public struct UpcomingJobCard: View {
    public let trip: Trip
    public let onTap: () -> Void

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(FMSTheme.pillBackground)
                        .frame(width: 48, height: 48)

                    Image(systemName: "truck.box.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(FMSTheme.textSecondary)
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(trip.endName ?? "Destination")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FMSTheme.textPrimary)
                        .lineLimit(1)

                    Text(scheduledText)
                        .font(.system(size: 13))
                        .foregroundStyle(FMSTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FMSTheme.textTertiary)
            }
            .padding(14)
            .background(FMSTheme.cardBackground)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(FMSTheme.borderLight, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var scheduledText: String {
        guard let time = trip.startTime else { return "Scheduled" }
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(time) {
            formatter.dateFormat = "'Scheduled:' h:mm a"
        } else if Calendar.current.isDateInTomorrow(time) {
            formatter.dateFormat = "'Scheduled: Tomorrow,' h:mm a"
        } else {
            formatter.dateFormat = "'Scheduled:' EEE, h:mm a"
        }
        return formatter.string(from: time)
    }
}
