import SwiftUI

// MARK: - Reorder a single part
struct ReorderPartView: View {
    let part: PartItem
    let store: InventoryStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var qtyString = ""
    @State private var confirmed = false

    private var qty: Int { Int(qtyString) ?? 0 }
    private var canOrder: Bool { qty > 0 }

    var body: some View {
        NavigationStack {
            ZStack {
                FMSTheme.bg(colorScheme).ignoresSafeArea()

                VStack(spacing: 20) {

                    // Part summary
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.8))
                                .frame(width: 64, height: 64)
                            Image(systemName: part.imageName)
                                .font(.system(size: 28))
                                .foregroundColor(FMSTheme.amber)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(part.name)
                                .font(.headline.weight(.bold))
                                .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                            Text(part.partNumber)
                                .font(.caption)
                                .foregroundColor(FMSTheme.textSecondary)
                            Text("Current stock: \(part.stock)  •  Min: \(part.minStock)")
                                .font(.caption)
                                .foregroundColor(part.isLowStock ? FMSTheme.alertOrange : FMSTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(colorScheme == .dark ? Color(red: 28/255, green: 28/255, blue: 30/255) : FMSTheme.cardBackground)
                    .cornerRadius(14)

                    // Qty input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ORDER QUANTITY")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(FMSTheme.textTertiary)
                            .tracking(0.6)

                        HStack(spacing: 12) {
                            Button {
                                let v = max(0, (Int(qtyString) ?? 0) - 1)
                                qtyString = v == 0 ? "" : "\(v)"
                            } label: {
                                Image(systemName: "minus")
                                    .frame(width: 44, height: 44)
                                    .background(Color.gray.opacity(0.1))
                                    .clipShape(Circle())
                                    .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                            }

                            TextField("0", text: $qtyString)
                                .keyboardType(.numberPad)
                                .font(.system(size: 28, weight: .bold))
                                .multilineTextAlignment(.center)
                                .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(Color.gray.opacity(0.08))
                                .cornerRadius(10)

                            Button {
                                qtyString = "\((Int(qtyString) ?? 0) + 1)"
                            } label: {
                                Image(systemName: "plus")
                                    .frame(width: 44, height: 44)
                                    .background(FMSTheme.amber.opacity(0.15))
                                    .clipShape(Circle())
                                    .foregroundColor(FMSTheme.amberDark)
                            }
                        }
                    }
                    .padding(16)
                    .background(colorScheme == .dark ? Color(red: 28/255, green: 28/255, blue: 30/255) : FMSTheme.cardBackground)
                    .cornerRadius(14)

                    if canOrder {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(FMSTheme.amberDark)
                            Text("Stock after order: \(part.stock + qty)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(colorScheme == .dark ? Color(red: 28/255, green: 28/255, blue: 30/255) : FMSTheme.cardBackground)
                        .cornerRadius(14)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    Spacer()

                    Button {
                        guard canOrder else { return }
                        store.reorder(part: part, quantity: qty)
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise.circle.fill").font(.system(size: 18))
                            Text("Place Order").font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(canOrder ? .black : FMSTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canOrder ? FMSTheme.amber : Color.gray.opacity(0.15))
                        .cornerRadius(14)
                    }
                    .disabled(!canOrder)
                    .animation(.easeInOut(duration: 0.2), value: canOrder)
                }
                .padding(16)
            }
            .navigationTitle("Reorder \(part.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(FMSTheme.textSecondary)
                }
            }
        }
    }
}

// MARK: - Bulk Reorder (low-stock items)
struct ReorderView: View {
    let store: InventoryStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var quantities: [UUID: String] = [:]

    private var lowParts: [PartItem] { store.lowStockParts }

    var body: some View {
        NavigationStack {
            ZStack {
                FMSTheme.bg(colorScheme).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        Text("Enter the quantity to reorder for each low-stock part.")
                            .font(.system(size: 13))
                            .foregroundColor(FMSTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        buildLowPartsList()

                        Button {
                            for part in lowParts {
                                if let q = Int(quantities[part.id] ?? ""), q > 0 {
                                    store.reorder(part: part, quantity: q)
                                }
                            }
                            dismiss()
                        } label: {
                            Text("Place All Orders")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(FMSTheme.amber)
                                .cornerRadius(14)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Bulk Reorder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(FMSTheme.textSecondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private func buildLowPartsList() -> some View {
        ForEach(lowParts) { part in
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.75))
                        .frame(width: 44, height: 44)
                    Image(systemName: part.imageName)
                        .font(.system(size: 18))
                        .foregroundColor(FMSTheme.amber)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(part.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                    Text("Stock: \(part.stock)  Min: \(part.minStock)")
                        .font(.caption)
                        .foregroundColor(FMSTheme.alertOrange)
                }
                Spacer()
                TextField("Qty", text: Binding(
                    get: { quantities[part.id] ?? "" },
                    set: { quantities[part.id] = $0 }
                ))
                .keyboardType(.numberPad)
                .font(.system(size: 16, weight: .bold))
                .multilineTextAlignment(.center)
                .frame(width: 60)
                .padding(8)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(8)
            }
            .padding(12)
            .background(colorScheme == .dark ? Color(red: 28/255, green: 28/255, blue: 30/255) : FMSTheme.cardBackground)
            .cornerRadius(12)
            .padding(.horizontal, 16)
        }
    }
}
