import SwiftUI

// ─────────────────────────────────────────────
// MARK: - Dashboard View
// ─────────────────────────────────────────────

public struct MaintenanceDashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State var woStore: WorkOrderStore
    @State var invStore = InventoryStore()
    @State private var showingCreateWO = false
    @State private var selectedFilter  = "All"
    
    @State private var isSearchActive  = false
    @State private var searchText      = ""

    let filters = ["All", "Pending", "In Progress", "Completed"]

    var filteredOrders: [WOItem] {
        var result = woStore.orders
        
        switch selectedFilter {
        case "Pending":     result = result.filter { $0.status == .pending }
        case "In Progress": result = result.filter { $0.status == .inProgress }
        case "Completed":   result = result.filter { $0.status == .completed }
        default:            break
        }
        
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let lower = searchText.lowercased()
            result = result.filter { item in
                item.woNumber.lowercased().contains(lower) ||
                item.vehicle.lowercased().contains(lower) ||
                item.description.lowercased().contains(lower)
            }
        }
        
        return result
    }

    private var cardBg: Color {
        colorScheme == .dark
            ? Color(red: 28/255, green: 28/255, blue: 30/255)
            : FMSTheme.cardBackground
    }


    public var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? FMSTheme.obsidian : FMSTheme.backgroundPrimary)
                    .ignoresSafeArea()

                VStack(spacing: 0) {

                    // Fixed title row
                    FMSTitleRow(title: "Dashboard")
                    Divider().opacity(0.35)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {

                            // Stat Cards (live from store)
                            HStack(spacing: 10) {
                                DashStatCard(title: "Pending",  value: "\(woStore.pendingCount)",
                                             icon: "clock.fill", color: FMSTheme.alertOrange)
                                DashStatCard(title: "In Prog",  value: "\(woStore.inProgressCount)",
                                             icon: "wrench.and.screwdriver.fill", color: FMSTheme.amberDark)
                                DashStatCard(title: "Done",     value: "\(woStore.completedCount)",
                                             icon: "checkmark.circle.fill", color: FMSTheme.alertGreen)
                            }
                            .padding(.horizontal, 16)

                            // Low Stock Banner
                            if invStore.lowStockParts.count > 0 {
                                lowStockBanner
                            }

                            // Work Orders Section
                            workOrdersSection
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingCreateWO, onDismiss: nil) {
                // Wrap CreateWorkOrderView in a container so the content closure is `() -> some View`
                CreateWorkOrderView { wo in
                    Task {
                        do {
                            let _ = try await woStore.add(wo)
                        } catch {
                            print("Error adding work order: \(error)")
                        }
                    }
                }
            }
        }
        .task {
            await woStore.fetchWorkOrders()
            await invStore.fetchParts()
        }
    }

    // MARK: - Low Stock Banner
    private var lowStockBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(FMSTheme.amber.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(FMSTheme.amberDark).font(.system(size: 17, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 3) {
                let lowCount = invStore.lowStockParts.count
                Text("\(lowCount) Part\(lowCount == 1 ? "" : "s") Low on Stock")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                Text("Reorder required to maintain fleet uptime")
                    .font(.system(size: 12)).foregroundColor(FMSTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold)).foregroundColor(FMSTheme.textTertiary)
        }
        .padding(14).background(cardBg).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(FMSTheme.amber.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: - Work Orders Section
    private var workOrdersSection: some View {
        VStack(alignment: .leading, spacing: 14) {

            FMSTitleRow(
                title: "Work Orders",
                onSearch: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isSearchActive.toggle()
                        if !isSearchActive {
                            searchText = ""
                        }
                    }
                },
                onAdd: { showingCreateWO = true }
            )

            // Dynamic Search Bar
            if isSearchActive {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(FMSTheme.textSecondary)
                    TextField("Search by ID, Vehicle, or Description...", text: $searchText)
                        .font(.system(size: 14))
                        .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                    
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(FMSTheme.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.gray.opacity(0.12))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(filters, id: \.self) { filter in
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                                selectedFilter = filter
                            }
                        } label: {
                            Text(filter).font(.system(size: 13, weight: .semibold))
                                .foregroundColor(selectedFilter == filter ? .black : FMSTheme.textSecondary)
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .background(Capsule().fill(selectedFilter == filter ? FMSTheme.amber : Color.gray.opacity(0.12)))
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            Text("\(filteredOrders.count) order\(filteredOrders.count == 1 ? "" : "s")")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(FMSTheme.textSecondary)
                .padding(.horizontal, 16)

            if woStore.isLoading {
                VStack {
                    ProgressView()
                        .padding()
                    Text("Loading orders...")
                        .font(.system(size: 14))
                        .foregroundColor(FMSTheme.textSecondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 24)
            } else if filteredOrders.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36)).foregroundColor(FMSTheme.textSecondary.opacity(0.4))
                    Text("No orders for this filter")
                        .font(.system(size: 14)).foregroundColor(FMSTheme.textSecondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 24)
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredOrders) { order in
                        NavigationLink(destination: WODetailView(wo: order, store: woStore)) {
                            DashWOCard(order: order, cardBg: cardBg)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Stat Card
// ─────────────────────────────────────────────

struct DashStatCard: View {
    let title: String; let value: String; let icon: String; let color: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(color.opacity(0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(FMSTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(FMSTheme.card(colorScheme))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(FMSTheme.borderLight.opacity(colorScheme == .dark ? 0.15 : 1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// ─────────────────────────────────────────────
// MARK: - Work Order Card (uses WOItem)
// ─────────────────────────────────────────────

struct DashWOCard: View {
    let order: WOItem
    let cardBg: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 3)
                .fill(order.priority.color)
                .frame(width: 4)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 10) {
                // Header row
                HStack(spacing: 10) {
                    // Icon block
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(order.priority.color.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 15))
                            .foregroundColor(order.priority.color)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        let parts = order.vehicle.components(separatedBy: " · ")
                        let plate = parts.count > 1 ? parts.last! : order.vehicle
                        let makeModel = parts.first ?? order.vehicle
                        
                        Text(plate)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                        Text(makeModel)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(FMSTheme.alertOrange)
                            .lineLimit(1)
                    }
                    Spacer()
                    // Status pill
                    HStack(spacing: 4) {
                        Circle().fill(order.status.color).frame(width: 6, height: 6)
                        Text(order.status.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(order.status.color)
                    }
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(order.status.color.opacity(0.1))
                    .clipShape(Capsule())
                }

                // Description
                Text(order.description)
                    .font(.system(size: 13))
                    .foregroundColor(FMSTheme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Footer
                HStack {
                    Label(order.priority.rawValue + " Priority",
                          systemImage: "flag.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(order.priority.color)
                    Spacer()
                    if let cost = order.estimatedCost {
                        Text("Est. $\(Int(cost))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(FMSTheme.textSecondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(FMSTheme.textTertiary)
                }
            }
            .padding(14)
        }
        .background(cardBg)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(FMSTheme.borderLight.opacity(colorScheme == .dark ? 0.15 : 1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

// ─────────────────────────────────────────────
// MARK: - Previews
// ─────────────────────────────────────────────

#Preview("Light") { MaintenanceDashboardView(woStore: WorkOrderStore()) }
#Preview("Dark")  { MaintenanceDashboardView(woStore: WorkOrderStore()).colorScheme(.dark) }

