import SwiftUI
internal import Auth
import Supabase

struct RecommendationDetailView: View {
    let vehicle: Vehicle
    let store: WorkOrderStore
    @Environment(\.dismiss) private var dismiss
    @Environment(BannerManager.self) private var bannerManager
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var description: String = ""
    @State private var priority: WOItem.Priority = .medium
    @State private var scheduledDate: Date = Date()
    @State private var notes: String = ""
    @State private var isCreating = false
    
    init(vehicle: Vehicle, store: WorkOrderStore) {
        self.vehicle = vehicle
        self.store = store
        _description = State(initialValue: "Routine maintenance for \(vehicle.plateNumber) based on usage.")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                FMSTheme.backgroundPrimary.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        vehicleInfoCard
                        recommendationDetailsSection
                        formSection
                        
                        Button {
                            createWorkOrder()
                        } label: {
                            HStack {
                                if isCreating {
                                    ProgressView().tint(.black).padding(.trailing, 8)
                                }
                                Image(systemName: "plus.circle.fill")
                                Text(isCreating ? "Creating..." : "Create Work Order")
                            }
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(FMSTheme.amber)
                            .cornerRadius(12)
                        }
                        .disabled(isCreating)
                        .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Service Recommendation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // Space for consistency or empty
                }
            }
        }
    }
    
    private var vehicleInfoCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(FMSTheme.amber.opacity(0.15))
                    .frame(width: 60, height: 60)
                Image(systemName: "truck.box.fill")
                    .foregroundColor(FMSTheme.amber)
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.plateNumber)
                    .font(.system(size: 20, weight: .bold))
                Text("\(vehicle.manufacturer ?? "") \(vehicle.model ?? "")")
                    .font(.system(size: 14))
                    .foregroundColor(FMSTheme.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background(FMSTheme.cardBackground)
        .cornerRadius(14)
    }
    
    private var recommendationDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(FMSTheme.alertOrange)
                Text("Recommendation Basis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(FMSTheme.textPrimary)
            }
            
            Text(MaintenancePredictionService.getStatusReason(for: vehicle))
                .font(.system(size: 15))
                .foregroundColor(FMSTheme.textPrimary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FMSTheme.alertOrange.opacity(0.12))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(FMSTheme.alertOrange.opacity(0.4), lineWidth: 1))
        }
    }
    
    private var formSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Work Order Description")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(FMSTheme.textSecondary)
                TextField("Description", text: $description, axis: .vertical)
                    .padding(12)
                    .background(FMSTheme.cardBackground)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(FMSTheme.borderLight, lineWidth: 1))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Priority")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(FMSTheme.textSecondary)
                Picker("Priority", selection: $priority) {
                    ForEach(WOItem.Priority.allCases, id: \.self) { p in
                        Text(p.rawValue.capitalized).tag(p)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                DatePicker("Scheduled Date", selection: $scheduledDate, displayedComponents: .date)
                    .font(.system(size: 14, weight: .medium))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Technician Notes (Reasoning/Constraints)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(FMSTheme.textSecondary)
                TextEditor(text: $notes)
                    .frame(height: 100)
                    .padding(8)
                    .background(FMSTheme.cardBackground)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(FMSTheme.borderLight, lineWidth: 1))
            }
        }
    }
    private func createWorkOrder() {
        isCreating = true
        Task {
            do {
                let reason = MaintenancePredictionService.getStatusReason(for: vehicle)
                let fullDetails = description + (notes.isEmpty ? "" : "\n\nNotes: \(notes)")
                let woDescription = "[SERVICE] \(reason)\n\n\(fullDetails)".trimmingCharacters(in: .whitespacesAndNewlines)
                
                var createdById: String? = nil
                if let session = try? await SupabaseService.shared.client.auth.session {
                    createdById = session.user.id.uuidString
                }
                
                let wo = MaintenanceWorkOrder(
                    id: UUID().uuidString,
                    vehicleId: vehicle.id,
                    createdBy: createdById,
                    assignedTo: nil,
                    description: woDescription,
                    priority: priority.rawValue.lowercased(),
                    status: "pending",
                    estimatedCost: nil,
                    createdAt: Date(),
                    completedAt: nil
                )
                
                try await store.add(wo)
                
                await MainActor.run {
                    isCreating = false
                    bannerManager.show(type: .success, message: "Work order created successfully")
                    dismiss()
                }
            } catch {
                print("Error creating work order from recommendation: \(error)")
                await MainActor.run {
                    isCreating = false
                    bannerManager.show(type: .error, message: "Failed to create work order")
                }
            }
        }
    }
}
