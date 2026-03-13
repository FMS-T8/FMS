import SwiftUI

struct PartDetailView: View {
    @State var part: PartItem
    let store: InventoryStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var showingEdit        = false
    @State private var showingReorder     = false
    @State private var showingDeleteAlert = false
    @State private var adjustQty: Int     = 0

    private var cardBg: Color {
        colorScheme == .dark ? Color(red: 28/255, green: 28/255, blue: 30/255) : FMSTheme.cardBackground
    }

    var body: some View {
        ZStack {
            (colorScheme == .dark ? FMSTheme.obsidian : FMSTheme.backgroundPrimary).ignoresSafeArea()

            VStack(spacing: 0) {

                // Custom nav bar
                HStack(spacing: 12) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                            .padding(10)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(part.name)
                            .font(.headline.weight(.bold))
                            .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                        Text(part.partNumber)
                            .font(.caption)
                            .foregroundColor(FMSTheme.textSecondary)
                    }

                    Spacer()

                    // Status badge
                    Text(part.isLowStock ? "LOW STOCK" : "IN STOCK")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(part.statusColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(part.statusColor.opacity(0.12))
                        .clipShape(Capsule())

                    // Edit button
                    Button { showingEdit = true } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                            .padding(10)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(colorScheme == .dark ? FMSTheme.obsidian : FMSTheme.cardBackground)

                Divider().opacity(0.4)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {

                        // Hero image
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.8))
                                .frame(height: 160)
                            Image(systemName: part.imageName)
                                .font(.system(size: 60))
                                .foregroundColor(FMSTheme.amber)
                        }
                        .padding(.horizontal, 16)

                        // Stats row
                        HStack(spacing: 12) {
                            DetailStatCard(title: "Current Stock", value: "\(part.stock)", icon: "cube.box.fill",
                                           color: part.statusColor)
                            DetailStatCard(title: "Min Threshold", value: "\(part.minStock)", icon: "arrow.down.to.line",
                                           color: FMSTheme.amberDark)
                            DetailStatCard(title: "Unit Cost",
                                           value: part.unitCost.map { "$\(String(format: "%.2f", $0))" } ?? "—",
                                           icon: "dollarsign.circle.fill", color: FMSTheme.textSecondary)
                        }
                        .padding(.horizontal, 16)

                        // Stock progress card
                        PDCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("STOCK LEVEL")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(FMSTheme.textTertiary)
                                    .tracking(0.6)

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.gray.opacity(0.15)).frame(height: 10)
                                        Capsule()
                                            .fill(part.statusColor)
                                            .frame(
                                                width: max(0, min(
                                                    geo.size.width,
                                                    geo.size.width * CGFloat(part.stock) / CGFloat(max(part.minStock * 2, 10))
                                                )),
                                                height: 10
                                            )
                                    }
                                }
                                .frame(height: 10)

                                HStack {
                                    Text("0")
                                        .font(.caption2)
                                        .foregroundColor(FMSTheme.textSecondary)
                                    Spacer()
                                    Text("Min: \(part.minStock)")
                                        .font(.caption2)
                                        .foregroundColor(FMSTheme.textSecondary)
                                    Spacer()
                                    Text("\(part.minStock * 2)+")
                                        .font(.caption2)
                                        .foregroundColor(FMSTheme.textSecondary)
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        // Quick stock adjustment
                        PDCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("ADJUST STOCK")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(FMSTheme.textTertiary)
                                    .tracking(0.6)

                                HStack(spacing: 16) {
                                    Button {
                                        withAnimation { adjustQty = max(adjustQty - 1, -part.stock) }
                                    } label: {
                                        Image(systemName: "minus")
                                            .font(.system(size: 16, weight: .bold))
                                            .frame(width: 44, height: 44)
                                            .background(Color.gray.opacity(0.1))
                                            .clipShape(Circle())
                                            .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                                    }

                                    Text(adjustQty >= 0 ? "+\(adjustQty)" : "\(adjustQty)")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(adjustQty > 0 ? FMSTheme.alertGreen : adjustQty < 0 ? FMSTheme.alertRed : FMSTheme.textSecondary)
                                        .frame(minWidth: 60)

                                    Button {
                                        withAnimation { adjustQty += 1 }
                                    } label: {
                                        Image(systemName: "plus")
                                            .font(.system(size: 16, weight: .bold))
                                            .frame(width: 44, height: 44)
                                            .background(FMSTheme.amber.opacity(0.15))
                                            .clipShape(Circle())
                                            .foregroundColor(FMSTheme.amberDark)
                                    }

                                    Spacer()

                                    Button {
                                        guard adjustQty != 0 else { return }
                                        Task {
                                            do {
                                                part.stock = max(0, part.stock + adjustQty)
                                                try await store.updatePart(part)
                                                await MainActor.run { adjustQty = 0 }
                                            } catch {
                                                print("Error adjusting stock: \(error)")
                                            }
                                        }
                                    } label: {
                                        Text("Apply")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(adjustQty != 0 ? .black : FMSTheme.textSecondary)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 10)
                                            .background(adjustQty != 0 ? FMSTheme.amber : Color.gray.opacity(0.12))
                                            .cornerRadius(10)
                                    }
                                    .disabled(adjustQty == 0)
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        Spacer().frame(height: 8)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }

                // Bottom actions
                VStack(spacing: 0) {
                    Divider().opacity(0.4)
                    HStack(spacing: 12) {
                        // Delete
                        Button { showingDeleteAlert = true } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 16))
                                .foregroundColor(FMSTheme.alertRed)
                                .frame(width: 50, height: 50)
                                .background(FMSTheme.alertRed.opacity(0.08))
                                .cornerRadius(12)
                        }

                        // Reorder
                        Button { showingReorder = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.system(size: 18))
                                Text("Reorder Stock")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(FMSTheme.amber)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(colorScheme == .dark ? FMSTheme.obsidian : FMSTheme.backgroundPrimary)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingEdit) {
            EditPartView(part: $part, store: store)
        }
        .sheet(isPresented: $showingReorder) {
            ReorderPartView(part: part, store: store)
        }
        .alert("Delete Part", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await store.deletePart(id: part.id)
                        await MainActor.run { dismiss() }
                    } catch {
                        print("Error deleting part: \(error)")
                    }
                }
            }
        } message: {
            Text("Remove \"\(part.name)\" from inventory? This can't be undone.")
        }
        .onChange(of: showingReorder) { _, isPresented in
            if !isPresented {
                if let updated = store.parts.first(where: { $0.id == part.id }) { part = updated }
            }
        }
        .onChange(of: showingEdit) { _, isPresented in
            if !isPresented {
                if let updated = store.parts.first(where: { $0.id == part.id }) { part = updated }
            }
        }
    }
}

// MARK: - Stat card
private struct DetailStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(FMSTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            colorScheme == .dark
                ? Color(red: 28/255, green: 28/255, blue: 30/255)
                : FMSTheme.cardBackground
        )
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - Card helper
private struct PDCard<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                colorScheme == .dark
                    ? Color(red: 28/255, green: 28/255, blue: 30/255)
                    : FMSTheme.cardBackground
            )
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.08), lineWidth: 1))
    }
}
