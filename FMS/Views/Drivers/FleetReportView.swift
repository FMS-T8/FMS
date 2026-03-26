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
  
  // PDF Export
  @State private var isGeneratingPDF = false
  @State private var pdfExportURL: URL?
  @State private var showPDFShareSheet = false
  
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
          // 2. Metrics Grid
          metricsGrid
            .padding(.horizontal)

          // Removed bottom export card to optimize space
        }
      }
    }
    .background(FMSTheme.backgroundPrimary)
    .navigationTitle("Fleet Report")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        HStack(spacing: 16) {
          if viewModel.selectedPreset != .thisWeek || viewModel.selectedVehicleId != nil
            || viewModel.selectedDriverId != nil
          {
            Button("Clear Filters") {
              viewModel.selectedPreset = .thisWeek
              viewModel.startDate = FleetReportViewModel.monday(for: Date())
              viewModel.endDate = Calendar.current.date(byAdding: .day, value: 6, to: viewModel.startDate) ?? Date()
              viewModel.selectedVehicleId = nil
              viewModel.selectedDriverId = nil
              Task { await loadData() }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(FMSTheme.amber)
          }

          Button {
              Task { await handlePDFGeneration() }
          } label: {
              if isGeneratingPDF {
                  ProgressView()
                      .tint(FMSTheme.amber)
              } else {
                  Image(systemName: "square.and.arrow.up")
                      .font(.system(size: 16, weight: .semibold))
                      .foregroundStyle(viewModel.isLoading ? FMSTheme.textTertiary : FMSTheme.amber)
              }
          }
          .disabled(viewModel.isLoading || isGeneratingPDF)
        }
      }
    }
    .task {
      // Initial load
      await viewModel.loadFilters()
      await loadData()
    }
    .onChange(of: viewModel.errorMessage) { _, msg in
      if let error = msg {
        bannerManager.show(type: .error, message: error)
        viewModel.errorMessage = nil
      }
    }
    .onDisappear {
      cleanupPDFExportFile()
    }
    .sheet(isPresented: $showPDFShareSheet) {
        if let url = pdfExportURL {
            ActivityView(activityItems: [url])
                .presentationDetents([.medium, .large])
        }
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
  }

  private func cleanupPDFExportFile() {
    guard let pdfExportURL else { return }
    try? FileManager.default.removeItem(at: pdfExportURL)
  }

  // MARK: - Filters

  private var weekSelector: some View {
    HStack(spacing: 14) {
      Button {
        viewModel.moveDateRange(by: -1)
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
        Text(viewModel.selectedPreset == .custom ? "Custom Range" : viewModel.selectedPreset.rawValue)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(FMSTheme.textSecondary)
        Text(viewModel.dateLabel)
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(FMSTheme.textPrimary)
      }
      .frame(maxWidth: .infinity)

      Button {
        viewModel.moveDateRange(by: 1)
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

        Button(action: { sheetMetric = .fuelLogs }) {
            VStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "fuelpump.fill")
                        .foregroundStyle(FMSTheme.amber)
                    Text("Fuel Used")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(FMSTheme.textSecondary)
                    Spacer()
                    Text(String(format: "%.1f L", viewModel.totalFuelLiters))
                        .font(.title3.bold())
                        .foregroundStyle(FMSTheme.textPrimary)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "indianrupeesign")
                        .foregroundStyle(FMSTheme.amber)
                    Text("Fuel Cost")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(FMSTheme.textSecondary)
                    Spacer()
                    Text(String(format: "₹%.0f", viewModel.totalFuelCost))
                        .font(.title3.bold())
                        .foregroundStyle(FMSTheme.textPrimary)
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
        .buttonStyle(.plain)
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

  // MARK: - PDF Generation

  @MainActor
  private func handlePDFGeneration() async {
      isGeneratingPDF = true
      defer { isGeneratingPDF = false }
      
      // Clear old
      cleanupPDFExportFile()
      
      let renderer = ImageRenderer(content: FleetPDFReportTemplate(viewModel: viewModel))
      let paperSize = CGSize(width: 595.2, height: 841.8)
      renderer.proposedSize = .init(paperSize)
      
      let fileName = "fleet-report-\(UUID().uuidString).pdf"
      let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
      
      renderer.render { size, context in
          var pdfBox = CGRect(origin: .zero, size: paperSize)
          guard let pdfContext = CGContext(fileURL as CFURL, mediaBox: &pdfBox, nil) else { return }
          pdfContext.beginPDFPage(nil)
          context(pdfContext)
          pdfContext.endPDFPage()
          pdfContext.closePDF()
      }
      
      self.pdfExportURL = fileURL
      self.showPDFShareSheet = true
  }
}

fileprivate struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

fileprivate enum FleetReportMetricDetail: String, Identifiable {
    case totalTrips, distance, fuelLogs, incidents, workOrders
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .totalTrips: return "Recent Trips"
        case .distance: return "Distance Traveled"
        case .fuelLogs: return "Fuel Logs"
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
            case .fuelLogs:
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
