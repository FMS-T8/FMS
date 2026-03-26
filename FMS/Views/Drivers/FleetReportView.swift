import SwiftUI

public struct FleetReportView: View {
  @Environment(BannerManager.self) private var bannerManager
  @State private var viewModel = FleetReportViewModel()

  // Pickers states
  @State private var showDatePicker = false
  @State private var showVehiclePicker = false
  @State private var showDriverPicker = false

  // Temporary draft dates for the custom date range sheet
  @State private var draftStartDate: Date = Date()
  @State private var draftEndDate: Date = Date()
  @State private var csvExportURL: URL?
  
  // Sheet Metric
  @State private var sheetMetric: FleetReportMetricDetail? = nil
  
  public init() {}

  public var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        weekSelector
          .padding(.horizontal)
          .padding(.top, 8)

        // 1. Filter Bar
        filterBar
          .padding(.horizontal)

        if viewModel.isLoading {
          ProgressView("Crunching fleet data...")
            .padding(.top, 50)
        } else {
          weeklySummarySection
            .padding(.horizontal)

          // 2. Metrics Grid
          metricsGrid
            .padding(.horizontal)

          driverRankingSection
            .padding(.horizontal)

          // 3. Email Subscription Toggle
          emailSubscriptionSection
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
      }
    }
    .background(FMSTheme.backgroundPrimary)
    .navigationTitle("Fleet Report")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        if !viewModel.isLoading {
          ShareLink(
            item: viewModel.weeklyCSVReport(),
            subject: Text("Weekly Fleet Performance Report"),
            message: Text("Exported weekly report")
          ) {
            Label("Export CSV", systemImage: "square.and.arrow.up")
          }
        }
      }
      ToolbarItem(placement: .topBarTrailing) {
        if viewModel.selectedPreset != .thisWeek || viewModel.selectedVehicleId != nil
          || viewModel.selectedDriverId != nil
        {
          Button("Clear Filters") {
            viewModel.selectedPreset = .thisWeek
            viewModel.selectedWeekStart = FleetReportViewModel.monday(for: Date())
            viewModel.selectedVehicleId = nil
            viewModel.selectedDriverId = nil
            Task { await loadData() }
          }
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(FMSTheme.amber)
        }
      }
    }
    .task {
      // Initial load
      await viewModel.loadFilters()
      await loadData()
      await viewModel.fetchSubscriptionStatus()
    }
    .onDisappear {
      cleanupCSVExportFile()
    }
    .sheet(isPresented: $showDatePicker) {
      NavigationStack {
        Form {
          DatePicker("Start Date", selection: $draftStartDate, displayedComponents: .date)
          DatePicker(
            "End Date", selection: $draftEndDate, in: draftStartDate..., displayedComponents: .date)
        }
        .navigationTitle("Custom Date Range")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
          draftStartDate = viewModel.startDate
          draftEndDate = viewModel.endDate
        }
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button("Cancel") {
              showDatePicker = false
            }
          }
          ToolbarItem(placement: .topBarTrailing) {
            Button("Apply") {
              viewModel.endDate = draftEndDate
              viewModel.startDate = draftStartDate
              showDatePicker = false
              viewModel.selectedPreset = .custom
              Task { await loadData() }
            }
            .fontWeight(.bold)
          }
        }
      }
      .presentationDetents([.medium, .large])
    }
    .sheet(item: $sheetMetric) { metric in
        NavigationStack {
            MetricDetailSheet(metric: metric, viewModel: viewModel)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
  }

  private func loadData() async {
    await viewModel.fetchReportData()
    if let error = viewModel.errorMessage {
      bannerManager.show(type: .error, message: error)
      viewModel.errorMessage = nil  // clear it after showing banner
    }

    do {
      csvExportURL = try createCSVExportFile(from: viewModel.weeklyCSVReport())
    } catch {
      csvExportURL = nil
      bannerManager.show(type: .error, message: "Could not prepare CSV export.")
    }
  }

  private func createCSVExportFile(from csvContent: String) throws -> URL {
    cleanupCSVExportFile()

    let fileName = "fleet-report-\(UUID().uuidString).csv"
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    let data = Data(csvContent.utf8)
    try data.write(to: fileURL, options: .atomic)
    return fileURL
  }

  private func cleanupCSVExportFile() {
    guard let csvExportURL else { return }
    try? FileManager.default.removeItem(at: csvExportURL)
  }

  // MARK: - Filters

  private var weekSelector: some View {
    HStack(spacing: 14) {
      Button {
        viewModel.moveWeek(by: -1)
        Task { await loadData() }
      } label: {
        Image(systemName: "chevron.left")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(FMSTheme.textPrimary)
          .frame(width: 32, height: 32)
          .background(FMSTheme.cardBackground)
          .clipShape(Circle())
      }

      VStack(spacing: 2) {
        Text("Weekly Report")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(FMSTheme.textSecondary)
        Text(viewModel.weekLabel)
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(FMSTheme.textPrimary)
      }
      .frame(maxWidth: .infinity)

      Button {
        viewModel.moveWeek(by: 1)
        Task { await loadData() }
      } label: {
        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(FMSTheme.textPrimary)
          .frame(width: 32, height: 32)
          .background(FMSTheme.cardBackground)
          .clipShape(Circle())
      }
    }
  }

  private var weeklySummarySection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Fleet Efficiency Summary")
        .font(.headline.weight(.bold))
        .foregroundStyle(FMSTheme.textPrimary)

      HStack(spacing: 12) {
        ReportMetricCard(
          icon: "gauge.with.dots.needle.67percent",
          title: "Avg Behavior Score",
          value: String(format: "%.1f", viewModel.averageBehaviorScore)
        )
        ReportMetricCard(
          icon: "road.lanes",
          title: "Total KM",
          value: String(format: "%.0f", viewModel.totalDistanceKm)
        )
      }
    }
  }

  private var filterBar: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        // Date Filter
        Menu {
          ForEach(FleetReportViewModel.DatePreset.allCases) { preset in
            Button(preset.rawValue) {
              if preset == .custom {
                showDatePicker = true
              } else {
                viewModel.selectedPreset = preset
                Task { await loadData() }
              }
            }
          }
        } label: {
          filterChip(
            icon: "calendar",
            text: viewModel.selectedPreset == .custom
              ? "Custom" : viewModel.selectedPreset.rawValue,
            isActive: true
          )
        }

        // Vehicle Filter
        Menu {
          Button("All Vehicles") {
            viewModel.selectedVehicleId = nil
            Task { await loadData() }
          }
          Divider()
          ForEach(viewModel.availableVehicles) { vehicle in
            Button(vehicle.plateNumber) {
              viewModel.selectedVehicleId = vehicle.id
              Task { await loadData() }
            }
          }
        } label: {
          let text =
            viewModel.availableVehicles.first(where: { $0.id == viewModel.selectedVehicleId })?
            .plateNumber ?? "All Vehicles"
          filterChip(icon: "truck.box", text: text, isActive: viewModel.selectedVehicleId != nil)
        }

        // Driver Filter
        Menu {
          Button("All Drivers") {
            viewModel.selectedDriverId = nil
            Task { await loadData() }
          }
          Divider()
          ForEach(viewModel.availableDrivers) { driver in
            Button(driver.name) {
              viewModel.selectedDriverId = driver.id
              Task { await loadData() }
            }
          }
        } label: {
          let text =
            viewModel.availableDrivers.first(where: { $0.id == viewModel.selectedDriverId })?.name
            ?? "All Drivers"
          filterChip(icon: "person.2", text: text, isActive: viewModel.selectedDriverId != nil)
        }
      }
    }
  }

  private func filterChip(icon: String, text: String, isActive: Bool) -> some View {
    HStack(spacing: 6) {
      Image(systemName: icon)
      Text(text)
      Image(systemName: "chevron.down")
        .font(.system(size: 10, weight: .bold))
    }
    .font(.system(size: 14, weight: .semibold))
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(isActive ? FMSTheme.amber.opacity(0.15) : FMSTheme.cardBackground)
    .foregroundStyle(isActive ? FMSTheme.amberDark : FMSTheme.textSecondary)
    .overlay(
      RoundedRectangle(cornerRadius: 20)
        .stroke(isActive ? FMSTheme.amber.opacity(0.3) : FMSTheme.borderLight, lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 20))
  }

  // MARK: - Metrics Grid

  private var metricsGrid: some View {
    let columns = [
      GridItem(.flexible(), spacing: 16),
      GridItem(.flexible(), spacing: 16),
    ]

    return VStack(spacing: 24) {
      // Trips & Distances
      VStack(alignment: .leading, spacing: 12) {
        Text("Operational")
          .font(.headline.weight(.bold))
          .foregroundStyle(FMSTheme.textPrimary)

        LazyVGrid(columns: columns, spacing: 16) {
            Button(action: { sheetMetric = .totalTrips }) {
                ReportMetricCard(
                    icon: "map.fill", title: "Total Trips",
                    value: "\(viewModel.totalTrips)",
                    subtitle: "\(viewModel.completedTrips) completed"
                )
            }
            .buttonStyle(.plain)
            
            Button(action: { sheetMetric = .distance }) {
                ReportMetricCard(
                    icon: "point.topleft.down.curvedto.point.bottomright.up", title: "Distance",
                    value: "\(Int(viewModel.totalDistanceKm)) km"
                )
            }
            .buttonStyle(.plain)
        }
      }

      // Fuel
      VStack(alignment: .leading, spacing: 12) {
        Text("Fuel & Efficiency")
          .font(.headline.weight(.bold))
          .foregroundStyle(FMSTheme.textPrimary)

        LazyVGrid(columns: columns, spacing: 16) {
            Button(action: { sheetMetric = .fuelUsed }) {
                ReportMetricCard(
                    icon: "fuelpump.fill", title: "Fuel Used",
                    value: String(format: "%.1f L", viewModel.totalFuelLiters)
                )
            }
            .buttonStyle(.plain)
            
            Button(action: { sheetMetric = .fuelCost }) {
                ReportMetricCard(
                    icon: "indianrupeesign", title: "Fuel Cost",
                    value: String(format: "₹%.0f", viewModel.totalFuelCost),
                    subtitle: String(format: "Avg %.1f km/L", viewModel.avgFuelEfficiency)
                )
            }
            .buttonStyle(.plain)
        }
      }

      // Safety & Maintenance
      VStack(alignment: .leading, spacing: 12) {
        Text("Safety & Maintenance")
          .font(.headline.weight(.bold))
          .foregroundStyle(FMSTheme.textPrimary)

        LazyVGrid(columns: columns, spacing: 16) {
            Button(action: { sheetMetric = .incidents }) {
                ReportMetricCard(
                    icon: "exclamationmark.triangle.fill", title: "Incidents",
                    value: "\(viewModel.incidentCount)",
                    subtitle: "\(viewModel.safetyEventCount) sensor events"
                )
            }
            .buttonStyle(.plain)
            
            Button(action: { sheetMetric = .workOrders }) {
                ReportMetricCard(
                    icon: "wrench.and.screwdriver.fill", title: "Work Orders",
                    value: "\(viewModel.activeMaintenanceCount)",
                    subtitle: "\(viewModel.completedMaintenanceCount) resolved"
                )
            }
            .buttonStyle(.plain)
        }
      }
    }
  }

  private var driverRankingSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Driver Behavior Rankings")
        .font(.headline.weight(.bold))
        .foregroundStyle(FMSTheme.textPrimary)

      rankingCard(title: "Top 5 Drivers", rows: viewModel.topDrivers)
      rankingCard(title: "Bottom 5 Drivers", rows: viewModel.bottomDrivers)
    }
  }

  private func rankingCard(title: String, rows: [FleetReportViewModel.DriverPerformance])
    -> some View
  {
    VStack(alignment: .leading, spacing: 10) {
      Text(title)
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(FMSTheme.textPrimary)

      if rows.isEmpty {
        Text("No driver data for selected week.")
          .font(.system(size: 12))
          .foregroundStyle(FMSTheme.textTertiary)
      } else {
        ForEach(rows) { row in
          HStack {
            Text(row.name)
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(FMSTheme.textPrimary)
            Spacer()
            Text(String(format: "%.1f", row.behaviorScore))
              .font(.system(size: 13, weight: .bold, design: .rounded))
              .foregroundStyle(row.behaviorScore >= 70 ? FMSTheme.alertGreen : FMSTheme.alertRed)
          }
          .padding(.vertical, 2)
        }
      }
    }
    .padding(14)
    .background(FMSTheme.cardBackground)
    .cornerRadius(12)
  }

  // MARK: - Email Subscription

  private var emailSubscriptionSection: some View {
    VStack(spacing: 0) {
      HStack(spacing: 16) {
        ZStack {
          Circle()
            .fill(FMSTheme.amber.opacity(0.15))
            .frame(width: 48, height: 48)
          Image(systemName: "envelope.fill")
            .font(.system(size: 20))
            .foregroundStyle(FMSTheme.amber)
        }

        VStack(alignment: .leading, spacing: 4) {
          Text("Automated Reports")
            .font(.headline.weight(.bold))
            .foregroundStyle(FMSTheme.textPrimary)

          Text("Receive this summary via email every Monday morning.")
            .font(.subheadline)
            .foregroundStyle(FMSTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer()

        Toggle(
          "",
          isOn: Binding(
            get: { viewModel.isSubscribedToEmail },
            set: { newValue in
              guard !viewModel.isTogglingSubscription else { return }
              Task { await viewModel.syncEmailSubscription(newValue) }
            }
          )
        )
        .labelsHidden()
        .accessibilityLabel("Email subscription")
        .tint(FMSTheme.amber)
        .disabled(viewModel.isTogglingSubscription)
      }
      .padding(16)
    }
    .background(FMSTheme.cardBackground)
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(FMSTheme.borderLight, lineWidth: 1)
    )
  }
}

fileprivate enum FleetReportMetricDetail: String, Identifiable {
    case totalTrips, distance, fuelUsed, fuelCost, incidents, workOrders
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .totalTrips: return "Recent Trips"
        case .distance: return "Distance Traveled"
        case .fuelUsed: return "Fuel Logs"
        case .fuelCost: return "Fuel Costs"
        case .incidents: return "Safety Incidents"
        case .workOrders: return "Work Orders"
        }
    }
}

fileprivate struct MetricDetailSheet: View {
    let metric: FleetReportMetricDetail
    let viewModel: FleetReportViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            switch metric {
            case .totalTrips:
                if viewModel.tripsData.isEmpty {
                    Text("No trips in this period")
                        .foregroundStyle(FMSTheme.textSecondary)
                } else {
                    ForEach(viewModel.tripsData) { trip in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Trip #\(trip.id.prefix(8).uppercased())")
                                .font(.headline)
                            if let desc = trip.shipment_description {
                                Text(desc)
                                    .font(.subheadline)
                                    .foregroundStyle(FMSTheme.textPrimary)
                            }
                            HStack {
                                Text("Status: \(trip.status?.capitalized ?? "Unknown")")
                                    .font(.subheadline)
                                    .foregroundStyle(FMSTheme.textSecondary)
                                Spacer()
                                if let d = trip.distance_km {
                                    Text("\(d, specifier: "%.1f") km")
                                        .font(.subheadline)
                                        .foregroundStyle(FMSTheme.textSecondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            case .distance:
                if viewModel.tripsData.isEmpty {
                    Section {
                        Text("No distance data in this period")
                            .foregroundStyle(FMSTheme.textSecondary)
                    }
                } else {
                    let validDistances = viewModel.tripsData.compactMap(\.distance_km).filter { $0 > 0 }
                    let sortedTrips = viewModel.tripsData.filter { ($0.distance_km ?? 0) > 0 }.sorted { ($0.distance_km ?? 0) > ($1.distance_km ?? 0) }
                    
                    Section(header: Text("Distance Highlights").font(.headline).textCase(nil).foregroundStyle(FMSTheme.textPrimary)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Average")
                                    .font(.caption)
                                    .foregroundStyle(FMSTheme.textSecondary)
                                let avg = validDistances.isEmpty ? 0 : (validDistances.reduce(0, +) / Double(validDistances.count))
                                Text("\(String(format: "%.1f", avg)) km")
                                    .font(.title3.bold())
                            }
                            Spacer()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Longest")
                                    .font(.caption)
                                    .foregroundStyle(FMSTheme.textSecondary)
                                Text("\(String(format: "%.1f", validDistances.max() ?? 0)) km")
                                    .font(.title3.bold())
                            }
                            Spacer()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Shortest")
                                    .font(.caption)
                                    .foregroundStyle(FMSTheme.textSecondary)
                                Text("\(String(format: "%.1f", validDistances.min() ?? 0)) km")
                                    .font(.title3.bold())
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Section(header: Text("All Trips by Distance").font(.headline).textCase(nil).foregroundStyle(FMSTheme.textPrimary)) {
                        ForEach(sortedTrips) { trip in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Trip #\(trip.id.prefix(8).uppercased())")
                                        .font(.subheadline.bold())
                                    if let desc = trip.shipment_description {
                                        Text(desc)
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }
                                }
                                Spacer()
                                Text("\(String(format: "%.1f", trip.distance_km ?? 0)) km")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(FMSTheme.amber)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            case .fuelUsed, .fuelCost:
                if viewModel.fuelData.isEmpty {
                    Text("No fuel logs in this period")
                        .foregroundStyle(FMSTheme.textSecondary)
                } else {
                    ForEach(viewModel.fuelData) { fuel in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top) {
                                Text(fuel.fuel_station ?? "Unknown Station")
                                    .font(.headline)
                                Spacer()
                                Text(formatDate(fuel.logged_at))
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            
                            if let driverId = fuel.driver_id,
                               let driverName = viewModel.availableDrivers.first(where: { $0.id == driverId })?.name {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.circle.fill")
                                    Text(driverName)
                                }
                                .font(.subheadline)
                                .foregroundStyle(FMSTheme.textSecondary)
                            }
                            
                            HStack {
                                if let vol = fuel.fuel_volume {
                                    Text("Volume: \(vol, specifier: "%.1f") L")
                                        .font(.subheadline)
                                }
                                Spacer()
                                if let amt = fuel.amount_paid {
                                    Text("Cost: ₹\(amt, specifier: "%.0f")")
                                        .font(.subheadline)
                                        .foregroundStyle(FMSTheme.textSecondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            case .incidents:
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sensor Events: \(viewModel.safetyEventCount)")
                            .font(.headline)
                        Text("Reported Incidents: \(viewModel.incidentCount)")
                            .font(.headline)
                    }
                    .padding(.vertical, 4)
                }
                
                if viewModel.incidentsData.isEmpty && viewModel.eventsData.isEmpty {
                    Section {
                        Text("No safety logs in this period")
                            .foregroundStyle(FMSTheme.textSecondary)
                    }
                } else {
                    if !viewModel.incidentsData.isEmpty {
                        Section(header: Text("Driver Incidents").font(.headline).textCase(nil).foregroundStyle(FMSTheme.textPrimary)) {
                            ForEach(viewModel.incidentsData) { incident in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .top) {
                                        Text(incident.severity?.replacingOccurrences(of: "_", with: " ").capitalized ?? "Incident")
                                            .font(.headline)
                                            .foregroundStyle(FMSTheme.alertRed)
                                        Spacer()
                                        if let dateString = incident.created_at {
                                            Text(formatDate(dateString))
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                    }
                                    Text("Incident #\(incident.id.prefix(8).uppercased())")
                                        .font(.caption2)
                                        .foregroundStyle(FMSTheme.textTertiary)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    
                    if !viewModel.eventsData.isEmpty {
                        Section(header: Text("Vehicle Events").font(.headline).textCase(nil).foregroundStyle(FMSTheme.textPrimary)) {
                            ForEach(viewModel.eventsData) { event in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .top) {
                                        Text(event.event_type?.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression, range: nil).capitalized ?? "Vehicle Event")
                                            .font(.headline)
                                            .foregroundStyle(FMSTheme.amber)
                                        Spacer()
                                        if let dateString = event.timestamp {
                                            Text(formatDate(dateString))
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                    }
                                    Text("Event log recorded")
                                        .font(.subheadline)
                                        .foregroundStyle(FMSTheme.textSecondary)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                }
            case .workOrders:
                if viewModel.maintenanceData.isEmpty {
                    Text("No work orders in this period")
                        .foregroundStyle(FMSTheme.textSecondary)
                } else {
                    ForEach(viewModel.maintenanceData) { order in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                Text(order.description?.split(separator: "\n").first.map(String.init) ?? "Maintenance Order")
                                    .font(.headline)
                                Spacer()
                                if let priorityStr = order.priority {
                                    let isHigh = priorityStr.lowercased() == "high"
                                    Text(priorityStr.capitalized)
                                        .font(.caption.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(isHigh ? FMSTheme.alertRed.opacity(0.15) : FMSTheme.amber.opacity(0.15))
                                        .foregroundStyle(isHigh ? FMSTheme.alertRed : FMSTheme.amber)
                                        .cornerRadius(8)
                                }
                            }
                            
                            HStack {
                                Text("Status: \(order.status?.replacingOccurrences(of: "_", with: " ").capitalized ?? "Unknown")")
                                    .font(.subheadline)
                                    .foregroundStyle(FMSTheme.textSecondary)
                                Spacer()
                                if let cost = order.estimated_cost {
                                    Text("Cost: ₹\(cost, specifier: "%.0f")")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(FMSTheme.textPrimary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(metric.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .fontWeight(.bold)
                .foregroundStyle(FMSTheme.amber)
            }
        }
    }
    
    private func formatDate(_ isoString: String?) -> String {
        guard let isoString = isoString else { return "Unknown Date" }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var dateObj = formatter.date(from: isoString)
        
        if dateObj == nil {
            formatter.formatOptions = [.withInternetDateTime]
            dateObj = formatter.date(from: isoString)
        }
        
        guard let date = dateObj else { return String(isoString.prefix(10)) }
        
        let outFormatter = DateFormatter()
        outFormatter.dateStyle = .medium
        outFormatter.timeStyle = .short
        return outFormatter.string(from: date)
    }
}

#Preview {
  NavigationStack {
    FleetReportView()
  }
  .environment(BannerManager())
}
