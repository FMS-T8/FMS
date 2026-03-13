import SwiftUI

public struct IncidentsListView: View {
    let incidents: [Incident]
    let isLoading: Bool
    let errorMessage: String?
    
    public init(incidents: [Incident], isLoading: Bool, errorMessage: String?) {
        self.incidents = incidents
        self.isLoading = isLoading
        self.errorMessage = errorMessage
    }
    
    public var body: some View {
        ZStack {
            FMSTheme.backgroundPrimary.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if isLoading {
                        loadingRow(text: "Loading incidents...")
                    } else if let error = errorMessage {
                        errorRow(text: "Unable to load incidents.\n\(error)")
                    } else if incidents.isEmpty {
                        emptyRow(text: "No incidents reported.")
                    } else {
                        VStack(spacing: 10) {
                            ForEach(incidents) { incident in
                                incidentCardView(incident)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Incidents")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
    
    private func incidentCardView(_ incident: Incident) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(incidentTitle(incident))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(FMSTheme.textPrimary)
                Spacer()
                Text(humanize(incident.severity ?? "Unknown").uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(FMSTheme.obsidian)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(FMSTheme.statusColor(for: incident.severity ?? "Unknown"))
                    .cornerRadius(6)
            }
            
            Text(incidentTimeText(incident))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(FMSTheme.textTertiary)
        }
        .padding(14)
        .background(FMSTheme.cardBackground)
        .cornerRadius(14)
        .shadow(color: FMSTheme.shadowSmall, radius: 4, x: 0, y: 3)
    }
    
    private func incidentTitle(_ incident: Incident) -> String {
        let severity = incident.severity?.trimmingCharacters(in: .whitespacesAndNewlines)
        return humanize(severity?.isEmpty == false ? severity! : "Incident")
    }
    
    private func incidentTimeText(_ incident: Incident) -> String {
        formatDate(incident.createdAt) ?? "Unknown"
    }
    
    private func loadingRow(text: String) -> some View {
        FMSListRow(text: text, textColor: FMSTheme.textSecondary, isLoading: true)
    }
    
    private func emptyRow(text: String) -> some View {
        FMSListRow(text: text, textColor: FMSTheme.textTertiary)
    }
    
    private func errorRow(text: String) -> some View {
        FMSListRow(systemImage: "exclamationmark.triangle.fill", text: text, textColor: FMSTheme.textSecondary)
    }
    
    private func formatDate(_ date: Date?) -> String? {
        SharedFormatting.formatDate(date)
    }
    
    private func humanize(_ value: String) -> String {
        SharedFormatting.humanize(value)
    }
}
