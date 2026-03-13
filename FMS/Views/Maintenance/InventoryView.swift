import SwiftUI

public struct InventoryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var store       = InventoryStore()
    @State private var showingAdd  = false
    @State private var searchText  = ""
    @State private var searchActive = false
    @State private var selectedFilter = "All"

    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    let stockFilters = ["All", "Low Stock", "In Stock"]

    var filteredParts: [PartItem] {
        var list = store.parts
        // Filter tab
        switch selectedFilter {
        case "Low Stock": list = list.filter(\.isLowStock)
        case "In Stock":  list = list.filter { !$0.isLowStock }
        default: break
        }
        // Search
        if !searchText.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.partNumber.localizedCaseInsensitiveContains(searchText)
            }
        }
        return list
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? FMSTheme.obsidian : FMSTheme.backgroundPrimary).ignoresSafeArea()

                VStack(spacing: 0) {

                    // ── Fixed Title Row ──────────────────────────────
                    FMSTitleRow(
                        title: "Inventory",
                        onSearch: { withAnimation(.spring(response: 0.3)) { searchActive.toggle() } },
                        onAdd: { showingAdd = true }
                    )

                    // Search bar (expandable)
                    if searchActive {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(FMSTheme.textSecondary)
                                .font(.system(size: 14))
                            TextField("Search parts…", text: $searchText)
                                .font(.system(size: 14))
                                .autocorrectionDisabled()
                            if !searchText.isEmpty {
                                Button { searchText = "" } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(FMSTheme.textSecondary)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Filter pills
                    FMSFilterBar(tabs: stockFilters, selected: $selectedFilter)

                    Divider().opacity(0.35)

                    // ── Scrollable Content ────────────────────────────
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {

                            // Low Stock Banner
                            if !store.lowStockParts.isEmpty && selectedFilter != "In Stock" && searchText.isEmpty {
                                LowStockBanner(count: store.lowStockParts.count, store: store)
                                    .padding(.horizontal, 16)
                            }

                            // Section header
                            HStack {
                                Text("Parts Catalog")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                                Spacer()
                                Text("\(filteredParts.count) \(filteredParts.count == 1 ? "item" : "items")")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(FMSTheme.textSecondary)
                            }
                            .padding(.horizontal, 16)

                            if store.isLoading && store.parts.isEmpty {
                                ProgressView("Loading Inventory...")
                                    .padding(.top, 48)
                            } else if filteredParts.isEmpty {
                                emptyState
                            } else {
                                // Grid
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(filteredParts) { part in
                                        NavigationLink(destination:
                                            PartDetailView(part: part, store: store)
                                        ) {
                                            PartCardView(part: part)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 28)
                            }
                        }
                        .padding(.top, 14)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAdd) {
                AddPartView { inv, icon in
                    Task {
                        do {
                            try await store.addPart(inv, imageName: icon)
                        } catch {
                            print("Error adding part: \(error)")
                        }
                    }
                }
            }
            .task {
                await store.fetchParts()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.system(size: 44))
                .foregroundColor(FMSTheme.textSecondary.opacity(0.4))
            Text("No parts found")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(FMSTheme.textSecondary)
            Text("Try a different filter or add a new part with +")
                .font(.system(size: 13))
                .foregroundColor(FMSTheme.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 48)
    }
}

// MARK: - Low Stock Banner (functional Order button)
struct LowStockBanner: View {
    let count: Int
    let store: InventoryStore
    @State private var showingReorder = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(FMSTheme.amber.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(FMSTheme.amberDark)
                    .font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count) Part\(count == 1 ? "" : "s") Below Threshold")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                Text("Tap Order to restock low items")
                    .font(.system(size: 12))
                    .foregroundColor(FMSTheme.textSecondary)
            }
            Spacer()
            Button("Order") { showingReorder = true }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(FMSTheme.amber)
                .cornerRadius(8)
        }
        .padding(12)
        .background(
            colorScheme == .dark
                ? Color(red: 28/255, green: 28/255, blue: 30/255)
                : FMSTheme.cardBackground
        )
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMSTheme.amber.opacity(0.3), lineWidth: 1))
        .sheet(isPresented: $showingReorder) {
            ReorderView(store: store)
        }
    }
}

// MARK: - Part Card
struct PartCardView: View {
    let part: PartItem
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Icon panel
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Rectangle()
                        .fill(colorScheme == .dark ? Color(red: 22/255, green: 22/255, blue: 24/255) : FMSTheme.obsidian)
                        .frame(height: 96)
                        .cornerRadius(14, corners: [.topLeft, .topRight])
                    Image(systemName: part.imageName)
                        .font(.system(size: 36))
                        .foregroundColor(FMSTheme.amber)
                }
                // Low-stock badge
                if part.isLowStock {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark").font(.system(size: 8, weight: .bold))
                        Text("LOW").font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(FMSTheme.alertOrange)
                    .cornerRadius(5)
                    .padding(8)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(part.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                        .lineLimit(1)
                    Text(part.partNumber)
                        .font(.system(size: 10))
                        .foregroundColor(FMSTheme.textTertiary)
                }

                // Stock row + bar
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("Stock: \(part.stock)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(part.statusColor)
                        Spacer()
                        Text("Min \(part.minStock)")
                            .font(.system(size: 10))
                            .foregroundColor(FMSTheme.textTertiary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(FMSTheme.borderLight)
                                .frame(height: 4)
                            Capsule()
                                .fill(part.statusColor)
                                .frame(
                                    width: max(0, min(
                                        geo.size.width,
                                        geo.size.width * CGFloat(part.stock) / CGFloat(max(part.minStock * 2, 10))
                                    )),
                                    height: 4
                                )
                        }
                    }
                    .frame(height: 4)
                }
            }
            .padding(10)
        }
        .background(FMSTheme.card(colorScheme))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    part.isLowStock
                        ? FMSTheme.alertOrange.opacity(0.4)
                        : FMSTheme.borderLight.opacity(colorScheme == .dark ? 0.15 : 1),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat; var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

#Preview {
    InventoryView()
}
