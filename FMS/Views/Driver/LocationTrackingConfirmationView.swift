//
//  LocationTrackingConfirmationView.swift
//  FMS
//
//  Created by NJ on 12/03/26.
//

import SwiftUI

public struct LocationTrackingConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    let trip: Trip

    public init(trip: Trip) {
        self.trip = trip
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Confirmation content — centered on screen
                VStack(spacing: 24) {
                    if accessibilityReduceMotion {
                        Image(systemName: "location.fill.viewfinder")
                            .font(.system(size: 64, weight: .light))
                            .foregroundStyle(FMSTheme.statusColor(for: "active"))
                    } else {
                        Image(systemName: "location.fill.viewfinder")
                            .font(.system(size: 64, weight: .light))
                            .foregroundStyle(FMSTheme.statusColor(for: "active"))
                            .symbolEffect(.pulse.byLayer, options: .repeating)
                    }

                    VStack(spacing: 10) {
                        Text("Location Sharing Active")
                            .font(.title.weight(.bold))
                            .foregroundStyle(FMSTheme.textPrimary)

                        Text("Your device is now broadcasting real-time coordinates. Dispatch and route tracking are recording this trip.")
                            .font(.body)
                            .foregroundStyle(FMSTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 32)
                    }
                }

                Spacer()

                // CTA — standard size matching other screens
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                        Text("Proceed to Route")
                            .font(.headline.weight(.bold))
                    }
                }
                .buttonStyle(.fmsPrimary)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .background(FMSTheme.backgroundPrimary)
            .navigationTitle("Trip Started")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(FMSTheme.textTertiary)
                    }
                    .accessibilityLabel("Close")
                    .accessibilityHint("Dismiss this screen")
                }
            }
        }
    }
}
