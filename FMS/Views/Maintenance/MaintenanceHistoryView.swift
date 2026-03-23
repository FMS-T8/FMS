import SwiftUI

public struct MaintenanceHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    var woStore: WorkOrderStore
    @State private var searchText = ""
    @State private var selectedFilter = "All"
    
    let filters = ["All", "Pending", "In Progress", "Completed"]
    
    public init(woStore: WorkOrderStore) {
        self.woStore = woStore
    }
    
    var filteredOrders: [WOItem] {
        var result = woStore.orders
        
        // Filter by Status
        if selectedFilter != "All" {
            let mappedStatus = WOItem.Status.from(selectedFilter)
            result = result.filter { $0.status == mappedStatus }
        }
        
        // Filter by Search
        if !searchText.isEmpty {
            result = result.filter { 
                $0.vehicle.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                $0.woNumber.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result.sorted { $0.createdAt > $1.createdAt }
    }
    
    private var cardBg: Color {
        colorScheme == .dark
            ? Color(red: 28/255, green: 28/255, blue: 30/255)
            : FMSTheme.cardBackground
    }
    
    private func countFor(_ filter: String) -> Int {
        switch filter {
        case "Pending":     return woStore.orders.filter { $0.status == .pending }.count
        case "In Progress": return woStore.orders.filter { $0.status == .inProgress }.count
        case "Completed":   return woStore.orders.filter { $0.status == .completed }.count
        default:            return woStore.orders.count
        }
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? FMSTheme.obsidian : FMSTheme.backgroundPrimary)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Work Order History")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(FMSTheme.textPrimary)
                        
                        Spacer()
                        
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(FMSTheme.textTertiary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    
                    // Filters & Search
                    VStack(spacing: 16) {
                        // Search
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(FMSTheme.textTertiary)
                            TextField("Search history...", text: $searchText)
                                .font(.system(size: 15))
                        }
                        .padding(12)
                        .background(colorScheme == .dark ? Color.white.opacity(0.05) : FMSTheme.cardBackground.opacity(0.5))
                        .cornerRadius(12)
                        
                        // Status Pills
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(filters, id: \.self) { filter in
                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedFilter = filter
                                        }
                                    } label: {
                                        let count = countFor(filter)
                                        Text("\(filter) (\(count))")
                                            .font(.system(size: 13, weight: .semibold))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(selectedFilter == filter ? FMSTheme.amber : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)))
                                            .foregroundColor(selectedFilter == filter ? .black : FMSTheme.textSecondary)
                                            .cornerRadius(20)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    
                    if filteredOrders.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(FMSTheme.textTertiary.opacity(0.5))
                            Text("No records found")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(FMSTheme.textSecondary)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 14) {
                                ForEach(filteredOrders) { order in
                                    NavigationLink(destination: WODetailView(wo: order, store: woStore, isReadOnly: true)) {
                                        DashWOCard(woItem: order, background: cardBg)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 32)
                        }
                    }
                }
            }
        }
    }
}
