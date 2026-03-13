import SwiftUI

struct DriverTripDetailView: View {
    let trip: Trip
    @Bindable var viewModel: DriverDashboardViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showIssueReport = false
    @State private var showPreTripInspection = false
    @State private var showPostTripInspection = false
    @State private var preTripInspectionCompleted = false
    @State private var postTripInspectionCompleted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                routeHeader
                tripInfoCard
                if trip.shipmentDescription != nil {
                    shipmentCard
                }
                actionButtons
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(FMSTheme.backgroundPrimary)
        .navigationTitle("Trip Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showIssueReport) {
            IssueReportView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $showPreTripInspection) {
            InspectionChecklistView(
                type: .preTrip,
                vehicleId: viewModel.assignedVehicle?.id ?? "VH-001",
                driverId: viewModel.driver.id,
                onCompletion: {
                    preTripInspectionCompleted = true
                }
            )
        }
        .fullScreenCover(isPresented: $showPostTripInspection) {
            InspectionChecklistView(
                type: .postTrip,
                vehicleId: viewModel.assignedVehicle?.id ?? "VH-001",
                driverId: viewModel.driver.id,
                onCompletion: {
                    postTripInspectionCompleted = true
                }
            )
        }
        .onChange(of: showPreTripInspection) { _, isShowing in
            if !isShowing {
                if preTripInspectionCompleted {
                    viewModel.startTrip(trip)
                    dismiss()
                }
                preTripInspectionCompleted = false
            }
        }
        .onChange(of: showPostTripInspection) { _, isShowing in
            if !isShowing {
                if postTripInspectionCompleted {
                    viewModel.endTrip()
                    dismiss()
                }
                postTripInspectionCompleted = false
            }
        }
    }

    // MARK: - Route Header

    private var routeHeader: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FROM")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FMSTheme.textTertiary)
                        .tracking(1)
                    Text(trip.startName ?? "Origin")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(FMSTheme.textPrimary)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FMSTheme.amber)
                    .padding(.top, 16)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("TO")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(FMSTheme.textTertiary)
                        .tracking(1)
                    Text(trip.endName ?? "Destination")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(FMSTheme.textPrimary)
                }
            }

            if let distance = trip.distanceKm {
                HStack {
                    Label(String(format: "%.0f km", distance), systemImage: "road.lanes")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FMSTheme.amber)
                }
            }
        }
        .padding(20)
        .background(FMSTheme.cardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(FMSTheme.borderLight, lineWidth: 1)
        )
    }

    // MARK: - Trip Info Card

    private var tripInfoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Trip Information")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)

            infoRow(label: "Trip ID", value: trip.id.uppercased())
            infoRow(label: "Vehicle", value: viewModel.assignedVehicle?.plateNumber ?? "—")
            infoRow(label: "Status", value: statusLabel, valueColor: statusColor)

            if let start = trip.startTime {
                infoRow(label: "Start Time", value: formatDateTime(start))
            }

            if let end = trip.endTime {
                infoRow(label: "End Time", value: formatDateTime(end))
            }

            if let duration = trip.actualDurationMin ?? trip.estimatedDurationMin {
                let label = trip.actualDurationMin != nil ? "Duration" : "Est. Duration"
                infoRow(label: label, value: duration.formattedDuration)
            }
        }
        .padding(16)
        .background(FMSTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(FMSTheme.borderLight, lineWidth: 1)
        )
    }

    // MARK: - Shipment Card

    private var shipmentCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Shipment Details")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)

            if let desc = trip.shipmentDescription {
                infoRow(label: "Description", value: desc)
            }

            if let weight = trip.shipmentWeightKg {
                infoRow(label: "Weight", value: String(format: "%.0f kg", weight))
            }

            if let count = trip.shipmentPackageCount {
                infoRow(label: "Packages", value: "\(count)")
            }

            if trip.fragile == true {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(FMSTheme.alertOrange)
                    Text("Fragile")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FMSTheme.alertOrange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(FMSTheme.alertOrange.opacity(0.12))
                .cornerRadius(8)
            }

            if let instructions = trip.specialInstructions, !instructions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Special Instructions")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FMSTheme.textTertiary)
                    Text(instructions)
                        .font(.system(size: 14))
                        .foregroundStyle(FMSTheme.textPrimary)
                }
            }
        }
        .padding(16)
        .background(FMSTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(FMSTheme.borderLight, lineWidth: 1)
        )
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionButtons: some View {
        if trip.status?.lowercased() == "scheduled" {
            Button {
                preTripInspectionCompleted = false
                showPreTripInspection = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Start Trip")
                        .font(.headline.weight(.bold))
                }
            }
            .buttonStyle(.fmsPrimary)
        }

        if trip.status?.lowercased() == "active" {
            VStack(spacing: 10) {
                Button {
                    postTripInspectionCompleted = false
                    showPostTripInspection = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 14, weight: .bold))
                        Text("End Trip")
                            .font(.headline.weight(.bold))
                    }
                }
                .buttonStyle(.fmsPrimary)

                Button {
                    showIssueReport = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.bubble.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Report Issue")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(FMSTheme.amber)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(FMSTheme.amber.opacity(0.12))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(FMSTheme.amber.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func infoRow(label: String, value: String, valueColor: Color = FMSTheme.textPrimary) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(FMSTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(valueColor)
        }
    }

    private var statusLabel: String {
        trip.statusLabel
    }

    private var statusColor: Color {
        FMSTheme.statusColor(for: trip.status ?? "")
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, h:mm a"
        return formatter.string(from: date)
    }

}
