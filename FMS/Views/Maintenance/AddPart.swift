import SwiftUI
internal import Auth
import Supabase

struct AddPartView: View {
    /// Callback delivers a real PartsInventory ready for persistence
    let onAdd: (PartsInventory, String) -> Void  // (model, imageName)

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var partName     = ""
    @State private var partNumber   = ""    // used as the id
    @State private var stockQty     = ""
    @State private var minThreshold = ""
    @State private var unitCostStr  = ""
    @State private var selectedIcon = "cube.box.fill"

    let icons = [
        "cube.box.fill", "drop.fill", "bolt.fill", "wind",
        "pause.rectangle.fill", "circle.fill", "arrow.triangle.2.circlepath",
        "wrench.fill", "gear", "flame.fill"
    ]

    private var canSubmit: Bool { !partName.isEmpty && Int(stockQty) != nil }

    private var lowStockWarning: Bool {
        let s = Int(stockQty) ?? 0; let m = Int(minThreshold) ?? 0
        return m > 0 && s <= m
    }

    init(onAdd: @escaping (PartsInventory, String) -> Void) {
        self.onAdd = onAdd
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FMSTheme.bg(colorScheme).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {

                        // Identity
                        APCard {
                            VStack(alignment: .leading, spacing: 16) {
                                APField(label: "PART NAME", placeholder: "e.g. Oil Filter",
                                        text: $partName, icon: "cube.box.fill")
                                Divider().opacity(0.4)
                                APField(label: "PART NUMBER / ID", placeholder: "e.g. PN-502-A",
                                        text: $partNumber, icon: "number")
                            }
                        }

                        // Icon picker
                        APCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("ICON").font(.system(size: 11, weight: .bold))
                                    .foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(icons, id: \.self) { icon in
                                            Button {
                                                withAnimation(.spring(response: 0.25)) { selectedIcon = icon }
                                            } label: {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(selectedIcon == icon ? FMSTheme.obsidian : Color.gray.opacity(0.1))
                                                        .frame(width: 48, height: 48)
                                                    Image(systemName: icon).font(.system(size: 20))
                                                        .foregroundColor(selectedIcon == icon ? FMSTheme.amber : FMSTheme.textSecondary)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Stock numbers
                        APCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("CURRENT STOCK").font(.system(size: 11, weight: .bold))
                                            .foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                        TextField("0", text: $stockQty).keyboardType(.numberPad)
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                                            .padding(12).background(Color.gray.opacity(0.08)).cornerRadius(10)
                                    }
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("MIN THRESHOLD").font(.system(size: 11, weight: .bold))
                                            .foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                        TextField("0", text: $minThreshold).keyboardType(.numberPad)
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                                            .padding(12).background(Color.gray.opacity(0.08)).cornerRadius(10)
                                    }
                                }
                                Divider().opacity(0.4)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("UNIT COST (OPTIONAL)").font(.system(size: 11, weight: .bold))
                                        .foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                    HStack(spacing: 10) {
                                        Text("$").font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(FMSTheme.textSecondary)
                                        TextField("0.00", text: $unitCostStr).keyboardType(.decimalPad)
                                            .font(.system(size: 15))
                                            .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                                    }
                                    .padding(12).background(Color.gray.opacity(0.08)).cornerRadius(10)
                                }
                            }
                        }

                        // Low-stock warning
                        if lowStockWarning {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(FMSTheme.amberDark)
                                Text("Stock is at or below threshold — will show as low stock")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                            }
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(FMSTheme.amber.opacity(0.1)).cornerRadius(12)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        // Submit
                        Button(action: submit) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill").font(.system(size: 18))
                                Text("Add to Inventory").font(.system(size: 16, weight: .bold))
                            }
                            .foregroundColor(canSubmit ? .black : FMSTheme.textSecondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(canSubmit ? FMSTheme.amber : Color.gray.opacity(0.15)).cornerRadius(14)
                        }
                        .disabled(!canSubmit)
                        .animation(.easeInOut(duration: 0.2), value: canSubmit)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Add Part").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(FMSTheme.textSecondary)
                }
            }
        }
    }

    private func submit() {
        Task {
            let inv = PartsInventory(
                id:          nil, // Let Supabase handle ID generation
                name:        partName,
                stock:       Int(stockQty) ?? 0,
                threshold:   Int(minThreshold) ?? 0,
                unitCost:    Double(unitCostStr),
                lastUpdated: Date()
            )
            
            await MainActor.run {
                onAdd(inv, selectedIcon)
                dismiss()
            }
        }
    }
}

// MARK: - Form helpers
private struct APCard<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        content.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(FMSTheme.card(colorScheme)).cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(FMSTheme.borderLight.opacity(colorScheme == .dark ? 0.15 : 1), lineWidth: 1))
    }
}

private struct APField: View {
    let label: String; let placeholder: String
    @Binding var text: String; let icon: String
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 11, weight: .bold))
                .foregroundColor(FMSTheme.textTertiary).tracking(0.6)
            HStack(spacing: 10) {
                Image(systemName: icon).foregroundColor(FMSTheme.amberDark).font(.system(size: 15))
                TextField(placeholder, text: $text).font(.system(size: 15))
                    .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
            }
            .padding(12).background(Color.gray.opacity(0.08)).cornerRadius(10)
        }
    }
}

#Preview {
    AddPartView { _, _ in }
}
