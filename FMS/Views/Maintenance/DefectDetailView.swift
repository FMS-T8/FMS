import SwiftUI

struct DefectDetailView: View {
    @State var defect: DefectItem
    let store: DefectStore
    let woStore: WorkOrderStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var showingEdit        = false
    @State private var showingDeleteAlert = false
    @State private var showingCreateWO    = false

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
                        Text(defect.title)
                            .font(.headline.weight(.bold))
                            .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                            .lineLimit(1)
                        Text(defect.vehicle)
                            .font(.caption)
                            .foregroundColor(FMSTheme.textSecondary)
                    }
                    Spacer()
                    Text(defect.priority.displayLabel)
                        .font(.caption2.weight(.bold))
                        .foregroundColor(defect.priority.color)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(defect.priority.color.opacity(0.12))
                        .clipShape(Capsule())
                    Button { showingEdit = true } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                            .padding(10)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(colorScheme == .dark ? FMSTheme.obsidian : FMSTheme.cardBackground)

                Divider().opacity(0.4)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {

                        // Hero icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(defect.priority.color.opacity(0.08))
                                .frame(height: 140)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(defect.priority.color.opacity(0.2), lineWidth: 1))
                            Image(systemName: defect.imageName)
                                .font(.system(size: 56))
                                .foregroundColor(defect.priority.color)
                        }
                        .padding(.horizontal, 16)

                        // Stat row
                        HStack(spacing: 12) {
                            DDStatCard(title: "Category", value: defect.category,
                                       icon: "tag.fill", color: FMSTheme.amberDark)
                            DDStatCard(title: "Reported", value: defect.reportedAgo,
                                       icon: "clock.fill", color: FMSTheme.textSecondary)
                            DDStatCard(title: "Status",
                                       value: defect.linkedWorkOrderId == nil ? "Open" : "W/O Raised",
                                       icon: "checkmark.shield.fill",
                                       color: defect.linkedWorkOrderId == nil ? FMSTheme.alertOrange : FMSTheme.alertGreen)
                        }
                        .padding(.horizontal, 16)

                        // Description card
                        DDCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("DESCRIPTION")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                Text(defect.description.isEmpty ? "No description provided." : defect.description)
                                    .font(.system(size: 14))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.85) : FMSTheme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.horizontal, 16)

                        // Linked Work Order badge (if any)
                        if let woId = defect.linkedWorkOrderId {
                            DDCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("LINKED WORK ORDER")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(FMSTheme.amber.opacity(0.12))
                                                .frame(width: 40, height: 40)
                                            Image(systemName: "doc.text.fill")
                                                .font(.system(size: 18))
                                                .foregroundColor(FMSTheme.amberDark)
                                        }
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(woId)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                                            Text("Work Order")
                                                .font(.caption)
                                                .foregroundColor(FMSTheme.textSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(FMSTheme.alertGreen)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        Spacer().frame(height: 8)
                    }
                    .padding(.top, 16).padding(.bottom, 28)
                }

                // Bottom actions
                VStack(spacing: 0) {
                    Divider().opacity(0.4)
                    HStack(spacing: 12) {
                        Button { showingDeleteAlert = true } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 16))
                                .foregroundColor(FMSTheme.alertRed)
                                .frame(width: 50, height: 50)
                                .background(FMSTheme.alertRed.opacity(0.08))
                                .cornerRadius(12)
                        }
                        if defect.linkedWorkOrderId == nil {
                            Button { showingCreateWO = true } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "pencil.and.list.clipboard").font(.system(size: 16))
                                    Text("Create Work Order").font(.system(size: 16, weight: .bold))
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(FMSTheme.amber)
                                .cornerRadius(12)
                            }
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 16))
                                Text("Work Order Raised").font(.system(size: 16, weight: .bold))
                            }
                            .foregroundColor(FMSTheme.alertGreen)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(FMSTheme.alertGreen.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(colorScheme == .dark ? FMSTheme.obsidian : FMSTheme.backgroundPrimary)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingEdit) {
            EditDefectView(defect: $defect, store: store)
        }
        .sheet(isPresented: $showingCreateWO) {
            CreateWorkOrderView(prefillVehicle: defect.vehicle) { newWO in
                Task {
                    do {
                        let insertedWO = try await woStore.addItem(WOItem(from: newWO))
                        defect.linkedWorkOrderId = insertedWO.id
                        do {
                            try await store.update(defect)
                        } catch {
                            // rollback logic
                            print("Error linking WO, rolling back..")
                            _ = try? await woStore.delete(id: insertedWO.id) // Need to verify error / API of delete
                            throw error
                        }
                    } catch {
                        print("Error creating WO and linking to defect details: \(error)")
                    }
                }
            }
        }
        .alert("Delete Defect", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.deleteDefect(id: defect.id)
                dismiss()
            }
        } message: {
            Text("Remove \"\(defect.title)\"? This cannot be undone.")
        }
    }
}

// MARK: - Helpers
private struct DDCard<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        content.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(colorScheme == .dark ? Color(red: 28/255, green: 28/255, blue: 30/255) : FMSTheme.cardBackground)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.08), lineWidth: 1))
    }
}

private struct DDStatCard: View {
    let title: String; let value: String; let icon: String; let color: Color
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 18)).foregroundColor(color)
            Text(value).font(.system(size: 13, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary).lineLimit(1)
            Text(title).font(.system(size: 10, weight: .medium))
                .foregroundColor(FMSTheme.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(colorScheme == .dark ? Color(red: 28/255, green: 28/255, blue: 30/255) : FMSTheme.cardBackground)
        .cornerRadius(14).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.08), lineWidth: 1))
    }
}
