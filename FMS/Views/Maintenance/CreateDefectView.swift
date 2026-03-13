import SwiftUI

public struct CreateDefectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AuthViewModel.self) private var authViewModel

    @State private var vehicleId = ""
    @State private var defectDescription = ""
    @State private var selectedPriority = "Medium"
    @State private var estimatedCostString = ""

    private let priorities = ["Low", "Medium", "High"]

    private var canSubmit: Bool { !vehicleId.isEmpty && !defectDescription.isEmpty }

    private var priorityColor: Color {
        switch selectedPriority {
        case "High":   return FMSTheme.alertRed
        case "Medium": return Color(red: 0.2, green: 0.5, blue: 1.0)
        default:       return FMSTheme.alertGreen
        }
    }
    var onAdd: ((MaintenanceWorkOrder) -> Void)?
    
    public init(onAdd: ((MaintenanceWorkOrder) -> Void)? = nil) {
        self.onAdd = onAdd
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                FMSTheme.bg(colorScheme).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // Vehicle
                        CDFormCard {
                            VStack(alignment: .leading, spacing: 8) {
                                CDFormLabel(text: "VEHICLE ID")
                                HStack(spacing: 10) {
                                    Image(systemName: "box.truck")
                                        .foregroundColor(FMSTheme.amberDark)
                                        .font(.system(size: 16))
                                    TextField("e.g. V-1021 or Unit 402", text: $vehicleId)
                                        .textInputAutocapitalization(.characters)
                                        .font(.system(size: 15))
                                        .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                                }
                                .padding(12)
                                .background(Color.gray.opacity(0.08))
                                .cornerRadius(10)
                            }
                        }

                        // Details
                        CDFormCard {
                            VStack(alignment: .leading, spacing: 16) {

                                // Priority
                                VStack(alignment: .leading, spacing: 8) {
                                    CDFormLabel(text: "PRIORITY")
                                    HStack(spacing: 8) {
                                        ForEach(priorities, id: \.self) { p in
                                            Button {
                                                withAnimation(.spring(response: 0.25)) { selectedPriority = p }
                                            } label: {
                                                Text(p)
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 10)
                                                    .background(selectedPriority == p ? priorityColor : Color.gray.opacity(0.1))
                                                    .foregroundColor(selectedPriority == p ? .white : FMSTheme.textSecondary)
                                                    .cornerRadius(9)
                                            }
                                        }
                                    }
                                }

                                Divider().opacity(0.4)

                                // Description
                                VStack(alignment: .leading, spacing: 8) {
                                    CDFormLabel(text: "DESCRIPTION")
                                    ZStack(alignment: .topLeading) {
                                        TextEditor(text: $defectDescription)
                                            .frame(minHeight: 110)
                                            .padding(10)
                                            .background(Color.gray.opacity(0.08))
                                            .cornerRadius(10)
                                        if defectDescription.isEmpty {
                                            Text("Describe the defect in detail…")
                                                .font(.system(size: 14))
                                                .foregroundColor(FMSTheme.textTertiary)
                                                .padding(.horizontal, 14).padding(.vertical, 18)
                                                .allowsHitTesting(false)
                                        }
                                    }
                                }

                                Divider().opacity(0.4)

                                // Est. Cost
                                VStack(alignment: .leading, spacing: 8) {
                                    CDFormLabel(text: "ESTIMATED COST (OPTIONAL)")
                                    HStack(spacing: 10) {
                                        Text("$")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(FMSTheme.textSecondary)
                                        TextField("0.00", text: $estimatedCostString)
                                            .keyboardType(.decimalPad)
                                            .font(.system(size: 15))
                                            .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                                    }
                                    .padding(12)
                                    .background(Color.gray.opacity(0.08))
                                    .cornerRadius(10)
                                }
                            }
                        }

                        // Ready preview
                        if canSubmit {
                            CDFormCard {
                                HStack(spacing: 10) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(FMSTheme.alertGreen)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Ready to submit")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                                        Text("\(selectedPriority) priority · Vehicle \(vehicleId)")
                                            .font(.caption).foregroundColor(FMSTheme.textSecondary)
                                    }
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        // Submit
                        Button(action: submitWorkOrder) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill").font(.system(size: 18))
                                Text("Create Work Order").font(.system(size: 16, weight: .bold))
                            }
                            .foregroundColor(canSubmit ? .black : FMSTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(canSubmit ? FMSTheme.amber : Color.gray.opacity(0.15))
                            .cornerRadius(14)
                        }
                        .disabled(!canSubmit)
                        .animation(.easeInOut(duration: 0.2), value: canSubmit)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("New Work Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(FMSTheme.textSecondary)
                }
            }
        }
    }

    private func submitWorkOrder() {
        let newWO = MaintenanceWorkOrder(
            id: UUID().uuidString,
            vehicleId: vehicleId,
            createdBy: authViewModel.currentUser?.name ?? "Maintenance Tech",
            assignedTo: nil,
            description: defectDescription.isEmpty ? nil : defectDescription,
            priority: selectedPriority,
            status: "Pending",
            estimatedCost: Double(estimatedCostString),
            createdAt: Date(),
            completedAt: nil
        )
        onAdd?(newWO)
        dismiss()
    }
}

private struct CDFormCard<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FMSTheme.card(colorScheme))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.08), lineWidth: 1))
    }
}

private struct CDFormLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(FMSTheme.textTertiary)
            .tracking(0.6)
    }
}

#Preview {
    CreateDefectView()
        .environment(AuthViewModel())
}
