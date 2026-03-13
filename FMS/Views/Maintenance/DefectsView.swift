import SwiftUI

public struct DefectsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State var store: DefectStore
    var woStore: WorkOrderStore
    @State private var selectedFilter  = "All"
    @State private var searchText      = ""
    @State private var searchActive    = false
    @State private var showingReport   = false

    let filters = ["All", "Critical", "Urgent", "Medium", "Low"]

    var filteredDefects: [DefectItem] {
        var list = store.defects
        switch selectedFilter {
        case "Critical": list = list.filter { $0.priority == .critical }
        case "Urgent":   list = list.filter { $0.priority == .urgent }
        case "Medium":   list = list.filter { $0.priority == .medium }
        case "Low":      list = list.filter { $0.priority == .low }
        default: break
        }
        if !searchText.isEmpty {
            list = list.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.vehicle.localizedCaseInsensitiveContains(searchText)
            }
        }
        return list
    }

    init(woStore: WorkOrderStore = WorkOrderStore(), defectStore: DefectStore = DefectStore()) {
        self.woStore = woStore
        self._store  = State(initialValue: defectStore)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? FMSTheme.obsidian : FMSTheme.backgroundPrimary).ignoresSafeArea()

                VStack(spacing: 0) {

                    // Fixed title row
                    FMSTitleRow(
                        title: "Defects",
                        onSearch: { withAnimation(.spring(response: 0.3)) { searchActive.toggle() } },
                        onAdd: { showingReport = true }
                    )

                    // Expandable search
                    if searchActive {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(FMSTheme.textSecondary).font(.system(size: 14))
                            TextField("Search defects…", text: $searchText)
                                .font(.system(size: 14)).autocorrectionDisabled()
                            if !searchText.isEmpty {
                                Button { searchText = "" } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(FMSTheme.textSecondary)
                                }
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(Color.gray.opacity(0.1)).cornerRadius(10)
                        .padding(.horizontal, 16).padding(.bottom, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    FMSFilterBar(tabs: filters, selected: $selectedFilter)
                    Divider().opacity(0.35)

                    if store.isLoading {
                        Spacer()
                        ProgressView("Loading defects…")
                            .foregroundColor(FMSTheme.textSecondary)
                        Spacer()
                    } else {
                        // Count
                        HStack {
                            Text("\(filteredDefects.count) defect\(filteredDefects.count == 1 ? "" : "s")")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(FMSTheme.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)

                        if filteredDefects.isEmpty {
                            Spacer()
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(FMSTheme.alertGreen.opacity(0.5))
                                Text("No defects found")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(FMSTheme.textSecondary)
                                Text("Add a new defect with + or change filter")
                                    .font(.system(size: 13))
                                    .foregroundColor(FMSTheme.textSecondary.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                            Spacer()
                        } else {
                            ScrollView(showsIndicators: false) {
                                LazyVStack(spacing: 12) {
                                    ForEach(filteredDefects) { defect in
                                        NavigationLink(destination:
                                            DefectDetailView(defect: defect, store: store, woStore: woStore)
                                        ) {
                                            DefectCardView(defect: defect, store: store, woStore: woStore)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 28)
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await store.fetchDefects()
            }
            .sheet(isPresented: $showingReport) {
                ReportDefectView(store: store)
            }
        }
    }
}

// MARK: - Defect Card
struct DefectCardView: View {
    @State var defect: DefectItem
    let store: DefectStore
    let woStore: WorkOrderStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingCreateWO = false

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 3)
                .fill(defect.priority.color)
                .frame(width: 4)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(defect.priority.color.opacity(0.12))
                            .frame(width: 42, height: 42)
                        Image(systemName: defect.imageName)
                            .font(.system(size: 20))
                            .foregroundColor(defect.priority.color)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(defect.priority.displayLabel)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(defect.priority.color)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(defect.priority.color.opacity(0.1))
                                .clipShape(Capsule())
                            Text(defect.reportedAgo)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(FMSTheme.textTertiary)
                        }
                        Text(defect.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(FMSTheme.textTertiary)
                }

                // Vehicle row
                HStack(spacing: 5) {
                    Image(systemName: "box.truck")
                        .font(.system(size: 11))
                        .foregroundColor(FMSTheme.textTertiary)
                    
                    let parts = defect.vehicle.components(separatedBy: " · ")
                    let plate = parts.count > 1 ? parts.last! : defect.vehicle
                    
                    Text(plate)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(FMSTheme.textSecondary)
                    Spacer()
                }

                Divider()
                    .background(FMSTheme.borderLight)

                // Footer: W/O status
                HStack {
                    Spacer()
                    if defect.linkedWorkOrderId != nil {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 12))
                            Text("W/O Created").font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(FMSTheme.alertGreen)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(FMSTheme.alertGreen.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(FMSTheme.alertGreen.opacity(0.3), lineWidth: 1))
                    } else {
                        Button { showingCreateWO = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "pencil.and.list.clipboard").font(.system(size: 12))
                                Text("Create W/O").font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(FMSTheme.amber)
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding(14)
        }
        .background(FMSTheme.card(colorScheme))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(FMSTheme.borderLight.opacity(colorScheme == .dark ? 0.15 : 1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        .sheet(isPresented: $showingCreateWO) {
            CreateWorkOrderView(prefillVehicle: defect.vehicle) { newWO in
                Task {
                    do {
                        let insertedWO = try await woStore.addItem(WOItem(from: newWO))
                        // Now physically link it in Supabase since WO exists
                        var updatedDefect = defect
                        updatedDefect.linkedWorkOrderId = insertedWO.id
                        try await store.update(updatedDefect)
                        await MainActor.run {
                            defect = updatedDefect
                        }
                    } catch {
                        print("Failed to cascade WO insertion to defect link: \(error)")
                    }
                }
            }
        }
    }
}

#Preview {
    DefectsView()
}
