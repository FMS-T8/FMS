import SwiftUI
import PostgREST
import Supabase

@MainActor
public struct WODetailView: View {
    @State private var wo: WOItem
    let store: WorkOrderStore
    var isReadOnly: Bool = false
    var onUpdate: (() async -> Void)? = nil
    
    public init(wo: WOItem, store: WorkOrderStore, isReadOnly: Bool = false, onUpdate: (() async -> Void)? = nil) {
        self._wo = State(initialValue: wo)
        self.store = store
        self.isReadOnly = isReadOnly
        self.onUpdate = onUpdate
    }
    @State private var invStore = InventoryStore()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(BannerManager.self) private var bannerManager

    @State private var showingDeleteAlert    = false
    @State private var showingCompleteAlert  = false
    @State private var showingAddPart        = false
    @State private var diagnosticNotes       = ""
    @State private var serviceOdometerInput: String = ""
    @State private var vehicle: Vehicle? = nil

    // Parts-used add form state
    @State private var selectedPartId: UUID? = nil
    @State private var puQty       = "1"
    @State private var puCost      = ""

    private var cardBg: Color {
        colorScheme == .dark ? Color(red: 28/255, green: 28/255, blue: 30/255) : FMSTheme.cardBackground
    }

    public var body: some View {
        ZStack {
            (colorScheme == .dark ? FMSTheme.obsidian : FMSTheme.backgroundPrimary).ignoresSafeArea()

            VStack(spacing: 0) {

                // Nav bar
                HStack(spacing: 12) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                            .padding(10).background(Color.gray.opacity(0.1)).clipShape(Circle())
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        let parts = wo.vehicle.components(separatedBy: " · ")
                        let plate = parts.count > 1 ? parts.last! : wo.vehicle
                        let makeModel = parts.first ?? wo.vehicle

                        Text(plate).font(.headline.weight(.bold))
                            .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                        Text(makeModel).font(.caption).foregroundColor(FMSTheme.textSecondary).lineLimit(1)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Circle().fill(wo.status.color).frame(width: 6, height: 6)
                        Text(wo.status.rawValue.uppercased()).font(.caption2.weight(.bold))
                            .foregroundColor(wo.status.color)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(wo.status.color.opacity(0.12)).clipShape(Capsule())
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(colorScheme == .dark ? FMSTheme.obsidian : FMSTheme.cardBackground)

                Divider().opacity(0.4)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {

                        // Stat row
                        HStack(spacing: 12) {
                            WDStatCard(title: "Priority", value: wo.priority.rawValue,
                                       icon: "flag.fill", color: wo.priority.color)
                            WDStatCard(title: "Assigned", value: wo.assignedTo ?? "Unassigned",
                                       icon: "person.fill", color: FMSTheme.amberDark)
                            WDStatCard(title: "Est. Cost",
                                       value: wo.estimatedCost.map { "$\(String(format: "%.0f", $0))" } ?? "—",
                                       icon: "dollarsign.circle.fill", color: FMSTheme.textSecondary)
                        }
                        .padding(.horizontal, 16)

                        // Description
                        WDCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("DESCRIPTION", systemImage: "doc.text")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                Text(wo.description.isEmpty ? "No description." : wo.description)
                                    .font(.system(size: 14))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.85) : FMSTheme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.horizontal, 16)

                        // Status toggle
                        WDCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("JOB STATUS").font(.system(size: 11, weight: .bold))
                                    .foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                    if !isReadOnly {
                                        HStack(spacing: 8) {
                                            ForEach(WOItem.Status.allCases, id: \.self) { s in
                                                let isAllowed: Bool = {
                                                    switch wo.status {
                                                    case .pending:
                                                        // From Pending, can only go to In Progress (or stay Pending). Cannot jump to Completed.
                                                        return s == .pending || s == .inProgress
                                                    case .inProgress:
                                                        // From In Progress, can only go to Completed (or stay InProgress). Cannot go backward to Pending.
                                                        return s == .inProgress || s == .completed
                                                    case .completed:
                                                        // From Completed, cannot go back anywhere.
                                                        return s == .completed
                                                    }
                                                }()
                                                
                                                Button {
                                                    // Strict Flow: Pending -> In Progress -> Completed
                                                    if !isAllowed { return }
                                                    
                                                    let newState = s
                                                    if newState == .completed && wo.status != .completed {
                                                        if wo.isService {
                                                            serviceOdometerInput = vehicle?.odometer != nil ? "\(Int(vehicle!.odometer!))" : ""
                                                            showingCompleteAlert = true
                                                            return
                                                        } else {
                                                            // For non-service (defect) orders, just complete without odometer
                                                            Task {
                                                                do {
                                                                    try await store.updateStatus(wo.id, status: .completed)
                                                                    if let onUpdate { await onUpdate() }
                                                                    await MainActor.run {
                                                                        withAnimation {
                                                                            wo.status = .completed
                                                                            wo.completedAt = Date()
                                                                        }
                                                                        bannerManager.show(type: .success, message: "Defect resolved.")
                                                                    }
                                                                } catch {
                                                                    print("Error completing defect: \(error)")
                                                                }
                                                            }
                                                            return
                                                        }
                                                    }
                                                    
                                                    Task {
                                                        do {
                                                            var updatedWO = wo
                                                            updatedWO.status = newState
                                                            try await store.update(updatedWO)
                                                            await MainActor.run {
                                                                withAnimation(.spring(response: 0.3)) { wo.status = newState }
                                                            }
                                                        } catch {
                                                            print("Error updating status: \(error)")
                                                        }
                                                    }
                                                } label: {
                                                    Text(s.rawValue).font(.system(size: 12, weight: .semibold))
                                                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                                                        .background(wo.status == s ? s.color : Color.gray.opacity(0.1))
                                                        .foregroundColor(wo.status == s ? .white : (!isAllowed ? FMSTheme.textTertiary : FMSTheme.textSecondary))
                                                        .cornerRadius(9)
                                                        .opacity(!isAllowed ? 0.3 : 1.0)
                                                }
                                                .disabled(!isAllowed)
                                            }
                                        }
                                    } else {
                                        HStack(spacing: 4) {
                                            Circle().fill(wo.status.color).frame(width: 6, height: 6)
                                            Text(wo.status.rawValue).font(.system(size: 13, weight: .bold))
                                                .foregroundColor(wo.status.color)
                                            Spacer()
                                        }
                                        .padding(10)
                                        .background(wo.status.color.opacity(0.1))
                                        .cornerRadius(10)
                                    }
                            }
                        }
                        .padding(.horizontal, 16)

                        // ── PARTS USED (MaintenancePartsUsed) ──────────────────
                        WDCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Label("PARTS USED", systemImage: "shippingbox.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                    Spacer()
                                    if !isReadOnly {
                                        Button {
                                            withAnimation(.spring(response: 0.3)) { showingAddPart.toggle() }
                                        } label: {
                                            Image(systemName: showingAddPart ? "xmark" : "plus")
                                                .font(.system(size: 12, weight: .bold)).foregroundColor(.black)
                                                .padding(8).background(FMSTheme.amber).clipShape(Circle())
                                        }
                                    }
                                }

                                if wo.partsUsed.isEmpty && !showingAddPart {
                                    Text("No parts logged yet.")
                                        .font(.system(size: 13)).foregroundColor(FMSTheme.textSecondary)
                                }

                                ForEach(wo.partsUsed, id: \.id) { part in
                                    HStack(spacing: 10) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(FMSTheme.amber.opacity(0.12)).frame(width: 34, height: 34)
                                            Image(systemName: "shippingbox")
                                                .font(.system(size: 14)).foregroundColor(FMSTheme.amberDark)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            let partName = invStore.parts.first(where: { $0.id.uuidString.lowercased() == part.partId?.lowercased() })?.name ?? part.partId ?? "Unknown Part"
                                            Text(partName)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                                            HStack(spacing: 8) {
                                                Label("Qty: \(part.quantity ?? 1)", systemImage: "cube")
                                                    .font(.caption).foregroundColor(FMSTheme.textSecondary)
                                                if let cost = part.cost {
                                                    Label("$\(String(format: "%.2f", cost))", systemImage: "dollarsign")
                                                        .font(.caption).foregroundColor(FMSTheme.textSecondary)
                                                }
                                            }
                                        }
                                        Spacer()
                                        if !isReadOnly {
                                            Button {
                                                let pId = part.id
                                                let wId = wo.id
                                                let qtyToRestore = part.quantity ?? 1
                                                let matchedPartId = part.partId ?? ""
                                                Task {
                                                    do {
                                                        if let p = invStore.parts.first(where: { $0.id.uuidString.lowercased() == matchedPartId.lowercased() }) {
                                                            try await invStore.reorder(part: p, quantity: qtyToRestore)
                                                            do {
                                                                try await store.removePartUsed(pId, from: wId)
                                                            } catch {
                                                                // Roll back the stock restore since removePartUsed failed
                                                                try? await invStore.reorder(part: p, quantity: -qtyToRestore)
                                                                throw error
                                                            }
                                                        } else {
                                                            try await store.removePartUsed(pId, from: wId)
                                                        }
                                                        await MainActor.run {
                                                            wo.partsUsed.removeAll { $0.id == pId }
                                                        }
                                                    } catch {
                                                        print("Error restoring stock or removing part used: \(error)")
                                                    }
                                                }
                                            } label: {
                                                Image(systemName: "trash").font(.system(size: 12))
                                                    .foregroundColor(FMSTheme.alertRed)
                                            }
                                        }
                                    }
                                    .padding(10)
                                    .background(FMSTheme.amber.opacity(0.06))
                                    .cornerRadius(10)
                                }

                                // Inline add form
                                if showingAddPart {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Divider()
                                        Text("LOG A PART").font(.system(size: 11, weight: .bold))
                                            .foregroundColor(FMSTheme.textTertiary).tracking(0.6)

                                        HStack(spacing: 8) {
                                            Image(systemName: "shippingbox")
                                                .foregroundColor(FMSTheme.amberDark).font(.system(size: 14))
                                            
                                            if invStore.isLoading {
                                                ProgressView()
                                                    .scaleEffect(0.7)
                                                Text("Loading inventory...")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(FMSTheme.textSecondary)
                                            } else if invStore.parts.isEmpty {
                 Text("No parts in inventory.")
                     .font(.system(size: 14))
                     .foregroundColor(FMSTheme.alertRed)
                                            } else {
                                                Picker("Select Part", selection: $selectedPartId) {
                                                    Text("Choose a part...").tag(UUID?.none)
                                                    ForEach(invStore.parts) { part in
                                                        let outOfStock = part.stock <= 0
                                                        Text("\(part.name) (\(part.stock) available)")
                                                            .tag(UUID?.some(part.id))
                                                            .foregroundColor(outOfStock ? FMSTheme.alertRed : FMSTheme.textPrimary)
                                                    }
                                                }
                                                .pickerStyle(MenuPickerStyle())
                                                .tint(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                                                .onChange(of: selectedPartId) { _, newValue in
                                                    // Auto-populate cost if the part has one
                                                    if let id = newValue, let part = invStore.parts.first(where: { $0.id == id }) {
                                                        if let cost = part.unitCost {
                                                            let qty = Int(puQty) ?? 1
                                                            puCost = String(format: "%.2f", cost * Double(qty))
                                                        } else {
                                                            puCost = "0.00"
                                                        }
                                                        
                                                        // Ensure selected quantity doesn't exceed stock
                                                        if let qty = Int(puQty), qty > part.stock {
                                                            puQty = String(max(1, part.stock))
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        .padding(10).background(Color.gray.opacity(0.08)).cornerRadius(9)

                                        HStack(spacing: 10) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("QTY").font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(FMSTheme.textTertiary)
                                                TextField("1", text: $puQty)
                                                    .keyboardType(.numberPad)
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                                                    .padding(10).background(Color.gray.opacity(0.08)).cornerRadius(9)
                                                    .onChange(of: puQty) { _, newValue in
                                                        // Validate against max stock
                                                        if let id = selectedPartId, let part = invStore.parts.first(where: { $0.id == id }) {
                                                            if let currentQty = Int(newValue) {
                                                                if currentQty > part.stock {
                                                                    puQty = String(part.stock) // cap at available
                                                                }
                                                                // Recalculate cost
                                                                if let cost = part.unitCost {
                                                                    let safeQty = Int(puQty) ?? 1
                                                                    puCost = String(format: "%.2f", cost * Double(safeQty))
                                                                }
                                                            }
                                                        }
                                                    }
                                            }
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("TOTAL COST ($)").font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(FMSTheme.textTertiary)
                                                TextField("0.00", text: $puCost).keyboardType(.decimalPad)
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                                                    .padding(10).background(Color.gray.opacity(0.08)).cornerRadius(9)
                                            }
                                        }

                                        let invalidSubmission = selectedPartId == nil || 
                                            invStore.parts.first(where:{ $0.id == selectedPartId })?.stock == 0 || 
                                            (Int(puQty) ?? 0) <= 0
                                            
                                        Button {
                                            guard let id = selectedPartId,
                                                  let selectedItem = invStore.parts.first(where: { $0.id == id }) else { return }
                                            
                                            let qty = Int(puQty) ?? 1
                                            let part = MaintenancePartsUsed(
                                                id:          UUID().uuidString,
                                                workOrderId: wo.woNumber,
                                                partId:      selectedItem.id.uuidString,
                                                quantity:    qty,
                                                cost:        Double(puCost)
                                            )
                                            
                                            // Deduct stock from the inventory using negative reorder quantity
                                            Task {
                                                do {
                                                    try await invStore.reorder(part: selectedItem, quantity: -qty)
                                                    do {
                                                        try await store.addPartUsed(part, to: wo.id)
                                                    } catch {
                                                        // Roll back the stock deduction since addPartUsed failed
                                                        try? await invStore.reorder(part: selectedItem, quantity: qty)
                                                        throw error
                                                    }
                                                    await MainActor.run {
                                                        withAnimation { wo.partsUsed.append(part) }
                                                        // Reset
                                                        selectedPartId = nil; puQty = "1"; puCost = ""
                                                        showingAddPart = false
                                                    }
                                                } catch {
                                                    print("Error logging part/reordering: \(error)")
                                                }
                                            }
                                        } label: {
                                            Text(invStore.parts.first(where:{ $0.id == selectedPartId })?.stock == 0 ? "Out of Stock" : "Log Part")
                                                .font(.system(size: 14, weight: .bold)).foregroundColor(.black)
                                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                                .background(invalidSubmission ? Color.gray.opacity(0.2) : FMSTheme.amber)
                                                .cornerRadius(10)
                                        }
                                        .disabled(invalidSubmission)
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        // Diagnostic notes
                        WDCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("DIAGNOSTIC NOTES", systemImage: "pencil.line")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                ZStack(alignment: .topLeading) {
                                    TextEditor(text: $diagnosticNotes).frame(minHeight: 90)
                                        .font(.system(size: 14)).scrollContentBackground(.hidden).background(Color.clear)
                                        .disabled(isReadOnly)
                                    if diagnosticNotes.isEmpty {
                                        Text("Add notes, findings, or next steps…")
                                            .font(.system(size: 14))
                                            .foregroundColor(FMSTheme.textSecondary.opacity(0.5))
                                            .allowsHitTesting(false).padding(.top, 8).padding(.leading, 4)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        // Timeline
                        WDCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("TIMELINE").font(.system(size: 11, weight: .bold))
                                    .foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                                TimelineRow(icon: "plus.circle.fill", color: FMSTheme.amberDark,
                                            title: "Created", subtitle: wo.createdAgo)
                                if let completed = wo.completedAt {
                                    TimelineRow(icon: "checkmark.circle.fill", color: FMSTheme.alertGreen,
                                                title: "Completed",
                                                subtitle: Calendar.current.isDateInToday(completed) ? "Today" : "Yesterday")
                                }
                                if !wo.partsUsed.isEmpty {
                                    TimelineRow(icon: "shippingbox.fill", color: FMSTheme.amberDark,
                                                title: "\(wo.partsUsed.count) part(s) used",
                                                subtitle: wo.partsUsed.compactMap { $0.partId }.joined(separator: ", "))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 16).padding(.bottom, 28)
                }

                // Bottom bar
                if !isReadOnly {
                    VStack(spacing: 0) {
                        Divider().opacity(0.4)
                        HStack(spacing: 12) {
                            Button { showingDeleteAlert = true } label: {
                                Image(systemName: "trash").font(.system(size: 16))
                                    .foregroundColor(FMSTheme.alertRed)
                                    .frame(width: 50, height: 50)
                                    .background(FMSTheme.alertRed.opacity(0.08)).cornerRadius(12)
                            }
                            Button {
                                if wo.status == .pending {
                                    // Start Job
                                    Task {
                                        do {
                                            var updatedWO = wo
                                            updatedWO.status = .inProgress
                                            try await store.update(updatedWO)
                                            await MainActor.run {
                                                withAnimation(.spring(response: 0.3)) { wo.status = .inProgress }
                                            }
                                        } catch {
                                            print("Error starting job: \(error)")
                                        }
                                    }
                                } else if wo.status == .inProgress {
                                    if wo.isService {
                                        // Complete Job (via alert for service reset)
                                        if let woOdo = wo.serviceOdometer {
                                            serviceOdometerInput = "\(Int(woOdo))"
                                        } else if let vOdo = vehicle?.odometer {
                                            serviceOdometerInput = "\(Int(vOdo))"
                                        } else {
                                            serviceOdometerInput = ""
                                        }
                                        showingCompleteAlert = true
                                    } else {
                                        // Direct completion for non-service (defect) orders
                                        Task {
                                            do {
                                                try await store.updateStatus(wo.id, status: .completed)
                                                if let onUpdate { await onUpdate() }
                                                await MainActor.run {
                                                    withAnimation {
                                                        wo.status = .completed
                                                        wo.completedAt = Date()
                                                    }
                                                    bannerManager.show(type: .success, message: "Defect resolved.")
                                                }
                                            } catch {
                                                print("Error completing defect: \(error)")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    if wo.status == .pending {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 14))
                                        Text("Start Job")
                                            .font(.system(size: 16, weight: .bold))
                                    } else {
                                        Image(systemName: wo.status == .completed ? "checkmark.circle.fill" : "checkmark.circle")
                                            .font(.system(size: 16))
                                        Text(wo.status == .completed ? "Completed" : "Complete Job")
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                }
                                .foregroundColor(wo.status == .completed ? FMSTheme.alertGreen : .black)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(wo.status == .completed ? FMSTheme.alertGreen.opacity(0.1) : FMSTheme.amber)
                                .cornerRadius(12)
                            }
                            .disabled(wo.status == .completed)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(colorScheme == .dark ? FMSTheme.obsidian : FMSTheme.backgroundPrimary)
                    }
                }
            }
        }
        .task {
            // Fetch vehicle for current odometer
            do {
                let v: Vehicle = try await SupabaseService.shared.client
                    .from("vehicles")
                    .select()
                    .eq("id", value: wo.vehicleIdRaw)
                    .single()
                    .execute()
                    .value
                await MainActor.run { self.vehicle = v }
            } catch {
                print("Error fetching vehicle for WO detail: \(error)")
            }
            
            await invStore.fetchParts()
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("Delete Work Order", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await store.delete(id: wo.id)
                        await MainActor.run { dismiss() }
                    } catch {
                        print("Error deleting work order: \(error)")
                    }
                }
            }
        } message: { Text("Remove \(wo.woNumber)? This cannot be undone.") }
        .alert("Complete Job", isPresented: $showingCompleteAlert) {
            TextField("Service Odometer", text: $serviceOdometerInput)
                .keyboardType(.numberPad)
            Button("Cancel", role: .cancel) {}
            Button("Confirm") {
                let id = wo.id
                let sanitized = serviceOdometerInput.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
                guard let newOdo = Double(sanitized) else { return }
                
                // Validate: reject negative or rollbacks
                let currentOdo = vehicle?.odometer ?? 0
                if newOdo < 0 || newOdo < currentOdo {
                    bannerManager.show(type: .error, message: "Odometer cannot be negative or less than current (\(Int(currentOdo)) km).")
                    return
                }
                Task {
                    do {
                        try await store.updateStatus(id, status: .completed, serviceOdometer: newOdo)
                        if let onUpdate { await onUpdate() }
                        await MainActor.run {
                            withAnimation {
                                wo.status = .completed
                                wo.completedAt = Date()
                                 wo.serviceOdometer = newOdo
                            }
                        }
                        await MainActor.run {
                            bannerManager.show(type: .success, message: "Job completed and tracking reset.")
                        }
                    } catch {
                        print("Error completing work order: \(error)")
                        await MainActor.run {
                            bannerManager.show(type: .error, message: "Failed to complete job: \(error.localizedDescription)")
                        }
                    }
                }
            }
        } message: { 
            let plate = wo.vehicle.components(separatedBy: " · ").last ?? wo.vehicle
            Text("Enter the current odometer reading for \(plate) to reset maintenance tracking and set status to OK.") 
        }
    }
}

// MARK: - Helpers
private struct TimelineRow: View {
    let icon: String; let color: Color; let title: String; let subtitle: String
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 18)).foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                Text(subtitle).font(.caption).foregroundColor(FMSTheme.textSecondary).lineLimit(1)
            }
        }
    }
}

private struct WDCard<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        content.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(FMSTheme.card(colorScheme)).cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(FMSTheme.borderLight.opacity(colorScheme == .dark ? 0.15 : 1), lineWidth: 1))
    }
}

private struct WDStatCard: View {
    let title: String; let value: String; let icon: String; let color: Color
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: icon).font(.system(size: 16)).foregroundColor(color)
            }
            Text(value).font(.system(size: 12, weight: .bold)).lineLimit(1)
                .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
            Text(title).font(.system(size: 10, weight: .medium))
                .foregroundColor(FMSTheme.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(FMSTheme.card(colorScheme)).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(FMSTheme.borderLight.opacity(colorScheme == .dark ? 0.15 : 1), lineWidth: 1))
    }
}
