import SwiftUI

public struct TripHistoryCard: View {
    public let trip: Trip

    public var body: some View {
        HStack(spacing: 0) {
            // Left status rail
            RoundedRectangle(cornerRadius: 2)
                .fill(statusColor)
                .frame(width: 4)
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 8) {
                // Top row: Trip ID + Status
                HStack {
                    Text(trip.id.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FMSTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(FMSTheme.pillBackground)
                        .cornerRadius(6)

                    Spacer()

                    Text(trip.statusLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.12))
                        .cornerRadius(6)
                }

                // Route
                Text(route)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FMSTheme.textPrimary)
                    .lineLimit(1)

                // Details row
                HStack(spacing: 12) {
                    if let date = displayDate {
                        Label(formattedDate(date), systemImage: "calendar")
                            .font(.system(size: 12))
                            .foregroundStyle(FMSTheme.textSecondary)
                    }

                    if let distance = trip.distanceKm {
                        Label(String(format: "%.0f km", distance), systemImage: "road.lanes")
                            .font(.system(size: 12))
                            .foregroundStyle(FMSTheme.textSecondary)
                    }

                    if let duration = trip.actualDurationMin ?? trip.estimatedDurationMin {
                        Label(duration.formattedDuration, systemImage: "clock")
                            .font(.system(size: 12))
                            .foregroundStyle(FMSTheme.textSecondary)
                    }
                }
            }
            .padding(.leading, 12)
            .padding(.vertical, 4)
        }
        .padding(12)
        .background(FMSTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(FMSTheme.borderLight, lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private var route: String {
        let from = trip.startName ?? "Origin"
        let to = trip.endName ?? "Destination"
        return "\(from) → \(to)"
    }

    private var statusColor: Color {
        FMSTheme.statusColor(for: trip.status ?? "")
    }

    private var displayDate: Date? {
        trip.endTime ?? trip.startTime
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else {
            formatter.dateFormat = "d MMM"
        }
        return formatter.string(from: date)
    }

}
