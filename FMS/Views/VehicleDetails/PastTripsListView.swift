import SwiftUI

public struct PastTripsListView: View {
    let trips: [Trip]
    let isLoading: Bool
    let errorMessage: String?
    
    public init(trips: [Trip], isLoading: Bool, errorMessage: String?) {
        self.trips = trips
        self.isLoading = isLoading
        self.errorMessage = errorMessage
    }
    
    public var body: some View {
        ZStack {
            FMSTheme.backgroundPrimary.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if isLoading {
                        loadingRow(text: "Loading trips...")
                    } else if let error = errorMessage {
                        errorRow(text: "Unable to load past trips.\n\(error)")
                    } else if trips.isEmpty {
                        emptyRow(text: "No past trips found.")
                    } else {
                        VStack(spacing: 10) {
                            ForEach(trips) { trip in
                                tripCardView(trip)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Past Trips")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
    
    private func tripCardView(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tripTitleText(trip))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(FMSTheme.textPrimary)
                .lineLimit(1)
            
            tripRouteRow(trip)
            
            HStack(spacing: 14) {
                infoPill(icon: "calendar", text: tripDateText(trip))
                infoPill(icon: "map.fill", text: tripDistanceText(trip))
                infoPill(icon: "clock.fill", text: tripDurationText(trip))
            }
        }
        .padding(14)
        .background(FMSTheme.cardBackground)
        .cornerRadius(14)
        .shadow(color: FMSTheme.shadowSmall, radius: 4, x: 0, y: 3)
    }
    
    private func tripTitleText(_ trip: Trip) -> String {
        trip.displayTitle
    }
    
    private func tripRouteRow(_ trip: Trip) -> some View {
        let texts = trip.routeTexts
        
        return HStack(spacing: 8) {
            Text(texts.startText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(FMSTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer(minLength: 8)
            
            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(FMSTheme.textTertiary)
            
            Spacer(minLength: 8)
            
            Text(texts.endText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(FMSTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
    
    private func tripRouteText(_ trip: Trip) -> String {
        trip.displayRoute
    }
    
    private func tripDateText(_ trip: Trip) -> String {
        let date = trip.startTime ?? trip.createdAt
        return formatDate(date) ?? "Unknown"
    }
    
    private func tripDistanceText(_ trip: Trip) -> String {
        guard let distance = trip.distanceKm else { return "-- km" }
        return String(format: "%.0f km", distance)
    }
    
    private func tripDurationText(_ trip: Trip) -> String {
        if let actual = trip.actualDurationMin {
            return "\(actual) min"
        }
        if let estimated = trip.estimatedDurationMin {
            return "\(estimated) min"
        }
        return "-- min"
    }
    
    private func infoPill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(FMSTheme.textTertiary)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(FMSTheme.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(FMSTheme.backgroundPrimary)
        .cornerRadius(6)
    }
    
    private func loadingRow(text: String) -> some View {
        HStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: FMSTheme.textSecondary))
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(FMSTheme.textSecondary)
            Spacer()
        }
        .padding(14)
        .background(FMSTheme.cardBackground)
        .cornerRadius(14)
    }
    
    private func emptyRow(text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(FMSTheme.textTertiary)
            Spacer()
        }
        .padding(14)
        .background(FMSTheme.cardBackground)
        .cornerRadius(14)
    }
    
    private func errorRow(text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(FMSTheme.alertOrange)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(FMSTheme.textSecondary)
            Spacer()
        }
        .padding(14)
        .background(FMSTheme.cardBackground)
        .cornerRadius(14)
    }
    
    private func formatDate(_ date: Date?) -> String? {
        SharedFormatting.formatDate(date)
    }
}
