import SwiftUI

struct EditPartView: View {
    @Binding var part: PartItem
    let store: InventoryStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var name       = ""
    @State private var partNumber = ""
    @State private var stock      = ""
    @State private var minStock   = ""
    @State private var unitCost   = ""

    var body: some View {
        NavigationStack {
            ZStack {
                FMSTheme.bg(colorScheme).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {

                        EPFormCard {
                            VStack(alignment: .leading, spacing: 16) {
                                EPField(label: "PART NAME", placeholder: "e.g. Oil Filter", text: $name, icon: "cube.box.fill")
                                Divider().opacity(0.4)
                                EPField(label: "PART NUMBER", placeholder: "e.g. PN-502-A", text: $partNumber, icon: "number")
                            }
                        }

                        EPFormCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("STOCK").font(.system(size: 11, weight: .bold)).foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                        TextField("0", text: $stock)
                                            .keyboardType(.numberPad)
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                                            .padding(12).background(Color.gray.opacity(0.08)).cornerRadius(10)
                                    }
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("MIN THRESHOLD").font(.system(size: 11, weight: .bold)).foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                        TextField("0", text: $minStock)
                                            .keyboardType(.numberPad)
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                                            .padding(12).background(Color.gray.opacity(0.08)).cornerRadius(10)
                                    }
                                }
                                Divider().opacity(0.4)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("UNIT COST (OPTIONAL)").font(.system(size: 11, weight: .bold)).foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                    HStack {
                                        Text("$").foregroundColor(FMSTheme.textSecondary).font(.system(size: 16, weight: .semibold))
                                        TextField("0.00", text: $unitCost).keyboardType(.decimalPad)
                                            .font(.system(size: 15))
                                            .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                                    }
                                    .padding(12).background(Color.gray.opacity(0.08)).cornerRadius(10)
                                }
                            }
                        }

                        Button {
                            part.name = name.isEmpty ? part.name : name
                            part.partNumber = partNumber.isEmpty ? part.partNumber : partNumber
                            if let s = Int(stock) { part.stock = s }
                            if let m = Int(minStock) { part.minStock = m }
                            part.unitCost = Double(unitCost)
                            store.updatePart(part)
                            dismiss()
                        } label: {
                            Text("Save Changes")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(FMSTheme.amber)
                                .cornerRadius(14)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Edit Part")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(FMSTheme.textSecondary)
                }
            }
            .onAppear {
                name = part.name
                partNumber = part.partNumber
                stock = "\(part.stock)"
                minStock = "\(part.minStock)"
                unitCost = part.unitCost.map { String(format: "%.2f", $0) } ?? ""
            }
        }
    }
}

private struct EPFormCard<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        content.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(FMSTheme.card(colorScheme)).cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.08), lineWidth: 1))
    }
}

private struct EPField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let icon: String
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 11, weight: .bold)).foregroundColor(FMSTheme.textTertiary).tracking(0.6)
            HStack(spacing: 10) {
                Image(systemName: icon).foregroundColor(FMSTheme.amberDark).font(.system(size: 15))
                TextField(placeholder, text: $text)
                    .font(.system(size: 15))
                    .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
            }
            .padding(12).background(Color.gray.opacity(0.08)).cornerRadius(10)
        }
    }
}
