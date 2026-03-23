import SwiftUI
internal import Auth
import Supabase

@MainActor
struct CreateWorkOrderView: View {
    let prefillVehicle: String
    let prefillDescription: String
    /// Callback delivers a real MaintenanceWorkOrder ready for persistence
    let onAdd: (MaintenanceWorkOrder) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var vehicle          = ""
    @State private var assignedTo       = ""
    @State private var description      = ""
    @State private var selectedPriority = WOItem.Priority.medium
    @State private var estimatedCost    = ""
    
    @State private var users: [User]    = []
    @State private var isLoadingUsers   = false
    
    @State private var vehicles: [Vehicle] = []
    @State private var isLoadingVehicles   = false

    private var canSubmit: Bool { !vehicle.isEmpty && !description.isEmpty }

    init(prefillVehicle: String = "", prefillDescription: String = "", onAdd: @escaping (MaintenanceWorkOrder) async throws -> Void) {
        self.prefillVehicle = prefillVehicle
        self.prefillDescription = prefillDescription
        self.onAdd = onAdd
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FMSTheme.bg(colorScheme).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {

                        WOCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("VEHICLE").font(.system(size: 11, weight: .bold)).foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                HStack(spacing: 10) {
                                    Image(systemName: "box.truck").foregroundColor(FMSTheme.amberDark).font(.system(size: 15))
                                    if isLoadingVehicles {
                                        ProgressView().scaleEffect(0.8)
                                        Text("Loading...").font(.system(size: 15)).foregroundColor(FMSTheme.textSecondary)
                                    } else {
                                        Picker("Select Vehicle", selection: $vehicle) {
                                            Text("Select a vehicle").tag("")
                                            ForEach(vehicles) { v in
                                                Text(v.plateNumber).tag(v.id)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                                        .disabled(!prefillVehicle.isEmpty)
                                        Spacer()
                                    }
                                }
                                .padding(12).background(Color.gray.opacity(0.08)).cornerRadius(10)
                            }
                        }

                        WOCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ASSIGN TO (OPTIONAL)").font(.system(size: 11, weight: .bold)).foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                HStack(spacing: 10) {
                                    Image(systemName: "person.fill").foregroundColor(FMSTheme.amberDark).font(.system(size: 15))
                                    if isLoadingUsers {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Loading...").font(.system(size: 15)).foregroundColor(FMSTheme.textSecondary)
                                    } else {
                                        Picker("Assign To", selection: $assignedTo) {
                                            Text("Unassigned").tag("")
                                            ForEach(users) { user in
                                                Text(user.name).tag(user.id)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .tint(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                                        Spacer()
                                    }
                                }
                                .padding(12).background(Color.gray.opacity(0.08)).cornerRadius(10)
                            }
                        }

                        WOCard {
                            VStack(alignment: .leading, spacing: 16) {

                                // Priority
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("PRIORITY").font(.system(size: 11, weight: .bold))
                                        .foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                    HStack(spacing: 8) {
                                        ForEach(WOItem.Priority.allCases, id: \.self) { p in
                                            Button {
                                                withAnimation(.spring(response: 0.25)) { selectedPriority = p }
                                            } label: {
                                                Text(p.rawValue).font(.system(size: 13, weight: .semibold))
                                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                                                    .background(selectedPriority == p ? p.color : Color.gray.opacity(0.1))
                                                    .foregroundColor(selectedPriority == p ? .white : FMSTheme.textSecondary)
                                                    .cornerRadius(9)
                                            }
                                        }
                                    }
                                }

                                Divider().opacity(0.4)

                                // Description
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("DESCRIPTION").font(.system(size: 11, weight: .bold))
                                        .foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                    ZStack(alignment: .topLeading) {
                                        TextEditor(text: $description).frame(minHeight: 90)
                                            .padding(10).background(Color.gray.opacity(0.08)).cornerRadius(10)
                                        if description.isEmpty {
                                            Text("Describe the work required…").font(.system(size: 14))
                                                .foregroundColor(FMSTheme.textTertiary)
                                                .padding(.horizontal, 14).padding(.vertical, 18)
                                                .allowsHitTesting(false)
                                        }
                                    }
                                }

                                Divider().opacity(0.4)

                                // Estimated cost
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("ESTIMATED COST (OPTIONAL)").font(.system(size: 11, weight: .bold))
                                        .foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                    HStack(spacing: 10) {
                                        Text("$").foregroundColor(FMSTheme.textSecondary)
                                            .font(.system(size: 16, weight: .semibold))
                                        TextField("0.00", text: $estimatedCost).keyboardType(.decimalPad)
                                            .font(.system(size: 15))
                                            .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                                    }
                                    .padding(12).background(Color.gray.opacity(0.08)).cornerRadius(10)
                                }
                            }
                        }

                        // Ready preview
                        if canSubmit {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(FMSTheme.amberDark)
                                Text("\(selectedPriority.rawValue) priority · \(vehicle)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                            }
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(FMSTheme.amber.opacity(0.1)).cornerRadius(12)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        Button(action: submit) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill").font(.system(size: 18))
                                Text("Create Work Order").font(.system(size: 16, weight: .bold))
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
            .navigationTitle("New Work Order").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(FMSTheme.textSecondary)
                }
            }
            .onAppear { 
                if !prefillVehicle.isEmpty { vehicle = prefillVehicle }
                if !prefillDescription.isEmpty { description = prefillDescription }
            }
            .task {
                await fetchData()
            }
        }
    }

    private func fetchData() async {
        isLoadingUsers = true
        isLoadingVehicles = true
        defer { isLoadingUsers = false; isLoadingVehicles = false }
        do {
            async let usersResp = SupabaseService.shared.client.from("users").select().execute()
            async let vehiclesResp = SupabaseService.shared.client.from("vehicles").select().execute()
            
            let (uResp, vResp) = try await (usersResp, vehiclesResp)
            
            let decoder = JSONDecoder()
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateStr = try container.decode(String.self)
                
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                if let date = dateFormatter.date(from: dateStr) { return date }
                
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                if let date = dateFormatter.date(from: dateStr) { return date }
                
                dateFormatter.dateFormat = "yyyy-MM-dd"
                if let date = dateFormatter.date(from: dateStr) { return date }
                
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(dateStr)")
            }
            
            let fetchedUsers = try decoder.decode([User].self, from: uResp.data)
            self.users = fetchedUsers
            
            let fetchedVehicles = try decoder.decode([Vehicle].self, from: vResp.data)
            self.vehicles = fetchedVehicles
        } catch {
            print("Failed to fetch data: \(error)")
        }
    }

    private func submit() {
        Task {
            var createdById: String? = nil
            do {
                let session = try await SupabaseService.shared.client.auth.session
                createdById = session.user.id.uuidString
            } catch {
                print("Could not get current user session: \(error)")
            }
            
            // Build the real MaintenanceWorkOrder
            let wo = MaintenanceWorkOrder(
                id:            UUID().uuidString,
                vehicleId:     vehicle,
                createdBy:     createdById,
                assignedTo:    assignedTo.isEmpty ? nil : assignedTo,
                description:   description,
                priority:      selectedPriority.rawValue.lowercased(),
                status:        "pending",
                estimatedCost: Double(estimatedCost),
                createdAt:     Date(),
                completedAt:   nil
            )
            
            do {
                try await onAdd(wo)
                await MainActor.run { dismiss() }
            } catch {
                print("Failed to submit work order: \(error)")
            }
        }
    }
}

// MARK: - Reusable form helpers
private struct WOCard<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        content.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(FMSTheme.card(colorScheme)).cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(FMSTheme.borderLight.opacity(colorScheme == .dark ? 0.15 : 1), lineWidth: 1))
    }
}

private struct WOField: View {
    let label: String; let placeholder: String
    @Binding var text: String; let icon: String
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
    CreateWorkOrderView { _ in }
}
