import SwiftUI

// WorkOrderDetailView — compile-safe stub.
// All live editing is handled by WODetailView (uses WOItem + WorkOrderStore).
public struct WorkOrderDetailView: View {
    let woNumber:    String
    let vehicle:     String
    let description: String
    let status:      String
    let priority:    String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    /// Init from the legacy MaintenanceWorkOrder model (still used by some older navigation paths).
    public init(maintenanceOrder wo: MaintenanceWorkOrder) {
        self.woNumber    = wo.id
        self.vehicle     = wo.vehicleId ?? "Unknown"
        self.description = wo.description ?? ""
        self.status      = wo.status ?? "Pending"
        self.priority    = wo.priority ?? "Medium"
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
                            .padding(10).background(Color.gray.opacity(0.1)).clipShape(Circle())
                            .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(woNumber).font(.headline.weight(.bold))
                            .foregroundColor(colorScheme == .dark ? .white : FMSTheme.textPrimary)
                        Text(vehicle).font(.caption).foregroundColor(FMSTheme.textSecondary)
                    }
                    Spacer()
                    Text(status.uppercased()).font(.caption2.weight(.bold))
                        .foregroundColor(FMSTheme.amberDark)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(FMSTheme.amber.opacity(0.15)).clipShape(Capsule())
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(colorScheme == .dark ? FMSTheme.obsidian : FMSTheme.cardBackground)

                Divider().opacity(0.4)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("DESCRIPTION").font(.system(size: 11, weight: .bold))
                            .foregroundColor(FMSTheme.textTertiary).tracking(0.6)
                        Text(description.isEmpty ? "No description." : description)
                            .font(.system(size: 14))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.85) : FMSTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(colorScheme == .dark ? Color(red: 28/255, green: 28/255, blue: 30/255) : FMSTheme.cardBackground)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.08), lineWidth: 1))
                    .padding(16)
                }
            }
        }
        .navigationBarHidden(true)
    }
}
