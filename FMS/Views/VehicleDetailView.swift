import SwiftUI

public struct VehicleDetailView: View {
    let vehicle: Vehicle
    @State private var viewModel = VehicleDetailViewModel()
    
    public init(vehicle: Vehicle) {
        self.vehicle = vehicle
    }
    
    public var body: some View {
        ZStack {
            FMSTheme.backgroundPrimary.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    headerBlock
                    shiftStatusCard
                    currentTripSection
                    pastTripsSection
                    serviceSection
                    incidentsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(vehicle.plateNumber)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            bottomActions
        }
        .task {
            await viewModel.fetch(vehicleId: vehicle.id)
        }
    }
    
    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(vehicleName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(FMSTheme.textPrimary)
                    
                    Text(vehicle.plateNumber)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(FMSTheme.textSecondary)
                    
                    Text("VIN: \(vehicle.chassisNumber)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(FMSTheme.textSecondary)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(FMSTheme.statusColor(for: vehicle.status ?? ""))
                        .frame(width: 8, height: 8)
                    Text((vehicle.status ?? "Unknown").uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(FMSTheme.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(FMSTheme.backgroundPrimary)
                .cornerRadius(8)
            }
            
            Divider()
                .overlay(FMSTheme.borderLight)
            
            detailRow(title: "Make", value: vehicle.manufacturer ?? "Unknown")
            detailRow(title: "Model", value: vehicle.model ?? "Unknown")
            detailRow(title: "Fuel Type", value: vehicle.fuelType.capitalized)
            detailRow(title: "Fuel Tank", value: "\(Int(vehicle.fuelTankCapacity)) L")
            detailRow(title: "Carrying Capacity", value: capacityText)
            detailRow(title: "Odometer", value: odometerText)
        }
        .padding(16)
        .background(FMSTheme.cardBackground)
        .cornerRadius(16)
        .shadow(color: FMSTheme.shadowSmall, radius: 6, x: 0, y: 4)
    }
    
    private var shiftStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shift Status")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(FMSTheme.textPrimary)
            
            if let error = viewModel.tripsErrorMessage {
                errorCard(text: "Unable to load trip status.\n\(error)")
            } else if let trip = activeOrLatestTrip {
                HStack {
                    Text(tripRoute(trip))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(FMSTheme.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    Text(tripStatusText(trip))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(FMSTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(FMSTheme.backgroundPrimary)
                        .cornerRadius(6)
                }
                
                ProgressView(value: shiftProgress(trip))
                    .progressViewStyle(LinearProgressViewStyle(tint: FMSTheme.amber))
                    .background(FMSTheme.borderLight)
                    .clipShape(Capsule())
                
                HStack {
                    Text(tripTimeWindowText(trip))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(FMSTheme.textTertiary)
                    Spacer()
                    Text(tripDurationText(trip))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(FMSTheme.textTertiary)
                }
            } else {
                Text("No recent trips found.")
                    .font(.system(size: 14))
                    .foregroundColor(FMSTheme.textTertiary)
            }
        }
        .padding(16)
        .background(FMSTheme.cardBackground)
        .cornerRadius(16)
        .shadow(color: FMSTheme.shadowSmall, radius: 6, x: 0, y: 4)
    }
    
    private var currentTripSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Current Trip", count: currentTrip == nil ? 0 : 1, isLoading: viewModel.isLoadingTrips)
            
            if viewModel.isLoadingTrips {
                loadingCard(text: "Loading current trip...")
            } else if let error = viewModel.tripsErrorMessage {
                errorCard(text: "Unable to load current trip.\n\(error)")
            } else if let trip = currentTrip {
                tripCard(trip)
            } else {
                emptyCard(text: "No active trip.")
            }
        }
    }
    
    private var pastTripsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Past Trips", count: pastTrips.count, isLoading: viewModel.isLoadingTrips)
            
            if viewModel.isLoadingTrips {
                loadingCard(text: "Loading trips...")
            } else if let error = viewModel.tripsErrorMessage {
                errorCard(text: "Unable to load past trips.\n\(error)")
            } else if pastTrips.isEmpty {
                emptyCard(text: "No past trips found.")
            } else {
                VStack(spacing: 10) {
                    ForEach(pastTrips) { trip in
                        tripCard(trip)
                    }
                }
            }
        }
    }
    
    private var serviceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Service History", count: viewModel.workOrders.count, isLoading: viewModel.isLoadingWorkOrders)
            
            if viewModel.isLoadingWorkOrders {
                loadingCard(text: "Loading service history...")
            } else if let error = viewModel.workOrdersErrorMessage {
                errorCard(text: "Unable to load service history.\n\(error)")
            } else if viewModel.workOrders.isEmpty {
                emptyCard(text: "No service history found.")
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.workOrders) { order in
                        serviceCard(order)
                    }
                }
            }
        }
    }
    
    private var incidentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Incidents", count: viewModel.incidents.count, isLoading: viewModel.isLoadingEvents)
            
            if viewModel.isLoadingEvents {
                loadingCard(text: "Loading incidents...")
            } else if let error = viewModel.incidentsErrorMessage {
                errorCard(text: "Unable to load incidents.\n\(error)")
            } else if viewModel.incidents.isEmpty {
                emptyCard(text: "No incidents reported.")
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.incidents) { incident in
                        incidentCard(incident)
                    }
                }
            }
        }
    }
    
    private func tripCard(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(tripRoute(trip))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(FMSTheme.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                Text(tripStatusText(trip))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(FMSTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(FMSTheme.backgroundPrimary)
                    .cornerRadius(6)
            }
            
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
    
    private func serviceCard(_ order: MaintenanceWorkOrder) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(order.description?.isEmpty == false ? order.description! : "Service Task")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(FMSTheme.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                Text((order.status ?? "Pending").uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(FMSTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(FMSTheme.backgroundPrimary)
                    .cornerRadius(6)
            }
            
            HStack(spacing: 14) {
                infoPill(icon: "calendar", text: workOrderDateText(order))
                infoPill(icon: "wrench.and.screwdriver.fill", text: order.priority?.capitalized ?? "Standard")
                infoPill(icon: "creditcard.fill", text: workOrderCostText(order))
            }
        }
        .padding(14)
        .background(FMSTheme.cardBackground)
        .cornerRadius(14)
        .shadow(color: FMSTheme.shadowSmall, radius: 4, x: 0, y: 3)
    }
    
    private func incidentCard(_ incident: Incident) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(incidentTitle(incident))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(FMSTheme.textPrimary)
                Spacer()
                Text((incident.severity ?? "Unknown").uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(FMSTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(FMSTheme.backgroundPrimary)
                    .cornerRadius(6)
            }
            
            Text(incidentTimeText(incident))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(FMSTheme.textTertiary)
        }
        .padding(14)
        .background(FMSTheme.cardBackground)
        .cornerRadius(14)
        .shadow(color: FMSTheme.shadowSmall, radius: 4, x: 0, y: 3)
    }
    
    private func sectionHeader(title: String, count: Int, isLoading: Bool) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(FMSTheme.textPrimary)
            Spacer()
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: FMSTheme.textSecondary))
            } else {
                Text("\(count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(FMSTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(FMSTheme.backgroundPrimary)
                    .cornerRadius(6)
            }
        }
    }
    
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(FMSTheme.textTertiary)
                .tracking(0.5)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(FMSTheme.textSecondary)
        }
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
    
    private var bottomActions: some View {
        HStack(spacing: 12) {
            Button {
                // Track Live action
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14, weight: .bold))
                        .rotationEffect(.degrees(45))
                        .offset(x: -2, y: 2)
                    Text("Track Live")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(FMSTheme.obsidian)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(FMSTheme.amber)
                .cornerRadius(12)
            }
            
            Button {
                // Schedule Service action
            } label: {
                Text("Schedule Service")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(FMSTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(FMSTheme.borderLight, lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(FMSTheme.backgroundPrimary)
    }
    
    private func loadingCard(text: String) -> some View {
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
    
    private func emptyCard(text: String) -> some View {
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
    
    private func errorCard(text: String) -> some View {
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
    
    private var vehicleName: String {
        let make = vehicle.manufacturer ?? ""
        let model = vehicle.model ?? ""
        let fullName = "\(make) \(model)".trimmingCharacters(in: .whitespaces)
        return fullName.isEmpty ? "Unknown Vehicle" : fullName
    }
    
    private var capacityText: String {
        guard let capacity = vehicle.carryingCapacity else { return "Unknown" }
        return "\(Int(capacity)) kg"
    }
    
    private var odometerText: String {
        guard let odometer = vehicle.odometer else { return "Unknown" }
        return "\(Int(odometer)) km"
    }
    
    private func tripRoute(_ trip: Trip) -> String {
        let start = trip.startName ?? "Start"
        let end = trip.endName ?? "End"
        return "\(start) -> \(end)"
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
    
    private func tripTimeWindowText(_ trip: Trip) -> String {
        let start = formatTime(trip.startTime)
        let end = formatTime(trip.endTime)
        if let start, let end {
            return "\(start) - \(end)"
        }
        if let start {
            return "\(start) - In Progress"
        }
        return "Schedule unavailable"
    }
    
    private func tripStatusText(_ trip: Trip) -> String {
        (trip.status ?? "Unknown").uppercased()
    }
    
    private func workOrderDateText(_ order: MaintenanceWorkOrder) -> String {
        let date = order.completedAt ?? order.createdAt
        return formatDate(date) ?? "Unknown"
    }
    
    private func workOrderCostText(_ order: MaintenanceWorkOrder) -> String {
        guard let cost = order.estimatedCost else { return "--" }
        return "INR \(Int(cost))"
    }
    
    private func incidentTitle(_ incident: Incident) -> String {
        let severity = incident.severity?.trimmingCharacters(in: .whitespacesAndNewlines)
        return severity?.isEmpty == false ? severity! : "Incident"
    }
    
    private func incidentTimeText(_ incident: Incident) -> String {
        formatDate(incident.createdAt) ?? "Unknown"
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter
    }()
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
    
    private func formatDate(_ date: Date?) -> String? {
        guard let date else { return nil }
        return Self.dateFormatter.string(from: date)
    }
    
    private func formatTime(_ date: Date?) -> String? {
        guard let date else { return nil }
        return Self.timeFormatter.string(from: date)
    }
    
    private var currentTrip: Trip? {
        viewModel.trips.first { trip in
            if trip.endTime == nil { return true }
            let status = trip.status?.lowercased() ?? ""
            return status == "in_progress" || status == "ongoing" || status == "active"
        }
    }
    
    private var pastTrips: [Trip] {
        if let currentTrip {
            return viewModel.trips.filter { $0.id != currentTrip.id }
        }
        return viewModel.trips
    }
    
    private var activeOrLatestTrip: Trip? {
        currentTrip ?? viewModel.trips.first
    }
    
    private func shiftProgress(_ trip: Trip) -> Double {
        guard let start = trip.startTime else { return 0 }
        guard let estimated = trip.estimatedDurationMin, estimated > 0 else { return 0 }
        let elapsed = Date().timeIntervalSince(start) / 60.0
        let progress = elapsed / Double(estimated)
        return max(0, min(progress, 1))
    }
}

#Preview {
    let vehicle = Vehicle(
        id: "1",
        plateNumber: "MH02H0942",
        chassisNumber: "JH4TB2H26CC000000",
        manufacturer: "TATA",
        model: "PRIMA 5530.S",
        fuelType: "diesel",
        fuelTankCapacity: 400,
        carryingCapacity: 12000,
        purchaseDateString: "2025-09-10",
        odometer: 125000,
        status: "active",
        createdBy: nil,
        createdAt: nil
    )
    
    NavigationStack {
        VehicleDetailView(vehicle: vehicle)
    }
}
