import SwiftUI
import PostgREST
import Supabase

struct ReportDefectView: View {
    let store: DefectStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedVehicleId    = ""    // UUID string passed to DB
    @State private var selectedPlate        = ""    // display text
    @State private var defectTitle          = ""
    @State private var description          = ""
    @State private var selectedPriority     = DefectItem.Priority.medium
    @State private var selectedCategory     = "mechanical"

    // Vehicle picker state
    @State private var vehicles: [Vehicle]  = []
    @State private var showingVehiclePicker = false
    @State private var loadingVehicles      = false

    // DB-compatible categories (must match defects_category_check constraint)
    let categories: [(display: String, value: String)] = [
        ("Mechanical",  "mechanical"),
        ("Electrical",  "electrical"),
        ("Tyres",       "tyres"),
        ("Brakes",      "brakes"),
        ("Body",        "body"),
        ("Other",       "other")
    ]

    private var canSubmit: Bool { !selectedVehicleId.isEmpty && !defectTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    init(store: DefectStore) {
        self.store = store
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FMSTheme.bg(colorScheme).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {

                        // Vehicle picker button
                        RDCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("VEHICLE").font(.system(size: 11, weight: .bold))
                                    .foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                Button {
                                    if vehicles.isEmpty { Task { await loadVehicles() } }
                                    showingVehiclePicker = true
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "box.truck")
                                            .foregroundColor(FMSTheme.amberDark).font(.system(size: 15))
                                        Text(selectedPlate.isEmpty ? "Select vehicle…" : selectedPlate)
                                            .font(.system(size: 15))
                                            .foregroundColor(selectedPlate.isEmpty
                                                ? FMSTheme.textTertiary
                                                : (colorScheme == .dark ? .white : FMSTheme.textPrimary))
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 13))
                                            .foregroundColor(FMSTheme.textTertiary)
                                    }
                                    .padding(12)
                                    .background(Color.gray.opacity(0.08))
                                    .cornerRadius(10)
                                }
                            }
                        }

                        // Category
                        RDCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("CATEGORY").font(.system(size: 11, weight: .bold))
                                    .foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(categories, id: \.value) { cat in
                                            Button {
                                                withAnimation(.spring(response: 0.25)) { selectedCategory = cat.value }
                                            } label: {
                                                Text(cat.display).font(.system(size: 13, weight: .semibold))
                                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                                    .background(selectedCategory == cat.value ? FMSTheme.amber : Color.gray.opacity(0.1))
                                                    .foregroundColor(selectedCategory == cat.value ? .black : FMSTheme.textSecondary)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Title + Priority + Description
                        RDCard {
                            VStack(alignment: .leading, spacing: 16) {
                                RDField(label: "DEFECT TITLE", placeholder: "e.g. Tyre Puncture – Front Right",
                                        text: $defectTitle, icon: "exclamationmark.triangle.fill")

                                Divider().opacity(0.4)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("PRIORITY").font(.system(size: 11, weight: .bold))
                                        .foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                    HStack(spacing: 8) {
                                        ForEach(DefectItem.Priority.allCases, id: \.self) { p in
                                            Button { withAnimation(.spring(response: 0.25)) { selectedPriority = p } } label: {
                                                Text(p.displayLabel).font(.system(size: 11, weight: .semibold))
                                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                                                    .background(selectedPriority == p ? p.color : Color.gray.opacity(0.1))
                                                    .foregroundColor(selectedPriority == p ? .white : FMSTheme.textSecondary)
                                                    .cornerRadius(9)
                                            }
                                        }
                                    }
                                }

                                Divider().opacity(0.4)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("DESCRIPTION (OPTIONAL)").font(.system(size: 11, weight: .bold))
                                        .foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                    ZStack(alignment: .topLeading) {
                                        TextEditor(text: $description).frame(minHeight: 80)
                                            .padding(10).background(Color.gray.opacity(0.08)).cornerRadius(10)
                                        if description.isEmpty {
                                            Text("Additional details…").font(.system(size: 14))
                                                .foregroundColor(FMSTheme.textTertiary)
                                                .padding(.horizontal, 14).padding(.vertical, 18)
                                                .allowsHitTesting(false)
                                        }
                                    }
                                }
                            }
                        }

                        // Summary preview
                        if canSubmit {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(FMSTheme.amberDark)
                                Text("\(selectedPriority.rawValue) · \(selectedCategory) · \(selectedPlate)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                            }
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(FMSTheme.amber.opacity(0.1)).cornerRadius(12)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        Button(action: submit) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 16))
                                Text("Report Defect").font(.system(size: 16, weight: .bold))
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
            .navigationTitle("Report Defect").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(FMSTheme.textSecondary)
                }
            }
            .task { await loadVehicles() }
        }
        // Vehicle picker sheet
        .sheet(isPresented: $showingVehiclePicker) {
            VehiclePickerSheet(
                vehicles: vehicles,
                isLoading: loadingVehicles,
                onSelect: { vehicle in
                    selectedVehicleId = vehicle.id
                    selectedPlate     = vehicle.plateNumber
                    showingVehiclePicker = false
                }
            )
        }
    }

    private func loadVehicles() async {
        guard vehicles.isEmpty else { return }
        loadingVehicles = true
        do {
            let fetched: [Vehicle] = try await SupabaseService.shared.client
                .from("vehicles")
                .select()
                .execute()
                .value
            await MainActor.run { self.vehicles = fetched }
        } catch {
            print("Error loading vehicles: \(error)")
        }
        loadingVehicles = false
    }

    private func submit() {
        let trimmedTitle = defectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let newDefect = DefectItem(
            title:       trimmedTitle,
            vehicle:     selectedVehicleId,   // store UUID in vehicle field (maps to vehicle_id in DB)
            category:    selectedCategory,
            priority:    selectedPriority,
            description: description,
            reportedAt:  Date()
        )
        Task {
            do {
                try await store.addDefect(newDefect)
                await MainActor.run { dismiss() }
            } catch {
                print("Error saving defect: \(error)")
            }
        }
    }
}

// MARK: - Vehicle Picker Sheet
struct VehiclePickerSheet: View {
    let vehicles: [Vehicle]
    let isLoading: Bool
    let onSelect: (Vehicle) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var search = ""

    var filtered: [Vehicle] {
        if search.isEmpty { return vehicles }
        return vehicles.filter { $0.plateNumber.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FMSTheme.bg(colorScheme).ignoresSafeArea()
                if isLoading {
                    ProgressView("Loading vehicles…")
                } else if vehicles.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "box.truck").font(.system(size: 40))
                            .foregroundColor(FMSTheme.textTertiary)
                        Text("No vehicles found").foregroundColor(FMSTheme.textSecondary)
                    }
                } else {
                    List(filtered) { vehicle in
                        Button { onSelect(vehicle) } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(FMSTheme.amber.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "box.truck")
                                        .font(.system(size: 16))
                                        .foregroundColor(FMSTheme.amberDark)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(vehicle.plateNumber)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                                    if let model = vehicle.model, let manufacturer = vehicle.manufacturer {
                                        Text("\(manufacturer) \(model)")
                                            .font(.caption)
                                            .foregroundColor(FMSTheme.textSecondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(FMSTheme.textTertiary)
                            }
                        }
                        .listRowBackground(FMSTheme.card(colorScheme))
                    }
                    .listStyle(.insetGrouped)
                    .searchable(text: $search, prompt: "Search by plate…")
                }
            }
            .navigationTitle("Select Vehicle")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Form helpers
private struct RDCard<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        content.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(FMSTheme.card(colorScheme)).cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.08), lineWidth: 1))
    }
}

private struct RDField: View {
    let label: String; let placeholder: String; @Binding var text: String; let icon: String
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 11, weight: .bold)).foregroundColor(FMSTheme.textTertiary).tracking(0.6)
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
    ReportDefectView(store: DefectStore())
}
