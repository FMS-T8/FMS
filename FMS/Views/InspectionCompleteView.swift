import SwiftUI

public struct InspectionCompleteView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: InspectionViewModel
    @State private var showSummary = false
    @State private var animateCheckmark = false

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Amber gradient header
                ZStack {
                    LinearGradient(
                        colors: [FMSTheme.amber.opacity(0.3), FMSTheme.amber.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 200)

                    // Checkmark badge
                    ZStack {
                        // Decorative dots
                        Circle()
                            .fill(FMSTheme.amber.opacity(0.3))
                            .frame(width: 16, height: 16)
                            .offset(x: 50, y: -30)

                        Circle()
                            .fill(FMSTheme.amber.opacity(0.2))
                            .frame(width: 10, height: 10)
                            .offset(x: 55, y: 15)

                        Circle()
                            .fill(FMSTheme.amber.opacity(0.25))
                            .frame(width: 12, height: 12)
                            .offset(x: -45, y: 25)

                        // Main circle
                        Circle()
                            .fill(FMSTheme.amber)
                            .frame(width: 80, height: 80)
                            .shadow(color: FMSTheme.amber.opacity(0.3), radius: 16, y: 4)

                        Image(systemName: "checkmark")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(FMSTheme.obsidian)
                            .scaleEffect(animateCheckmark ? 1 : 0.5)
                            .opacity(animateCheckmark ? 1 : 0)
                    }
                    .offset(y: 20)
                }

                Spacer().frame(height: 32)

                // Status text
                VStack(spacing: 8) {
                    Text("Inspection Complete")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(FMSTheme.textPrimary)

                    Group {
                        if viewModel.checklist.inspectionType == .preTrip {
                            Text("Your vehicle status has been updated to ")
                                + Text(viewModel.vehicleStatus)
                                    .fontWeight(.bold)
                                + Text(viewModel.checklist.allPassed ? ". Have a safe trip!" : ". Please review flagged items.")
                        } else {
                            Text("Post-trip inspection recorded. Vehicle status: ")
                                + Text(viewModel.vehicleStatus)
                                    .fontWeight(.bold)
                                + Text(". Thank you for completing your trip safely.")
                        }
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(FMSTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                }

                Spacer().frame(height: 32)

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: viewModel.checklist.inspectionType == .preTrip ? "play.fill" : "checkmark.circle.fill")
                                .font(.system(size: 12))
                            Text(viewModel.checklist.inspectionType == .preTrip ? "Start Route" : "Trip Completed")
                                .font(.headline.weight(.bold))
                        }
                    }
                    .buttonStyle(.fmsPrimary)
                    .padding(.horizontal, 40)

                    Button {
                        showSummary = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 14))
                            Text("View Summary")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(FMSTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(FMSTheme.amber, lineWidth: 1.5)
                        )
                    }
                    .padding(.horizontal, 40)
                }

                Spacer()
            }
            .background(FMSTheme.backgroundPrimary)
            .navigationTitle("\(viewModel.checklist.inspectionType.rawValue) Inspection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            viewModel.showingExportSheet = true
                        } label: {
                            Label("Export Report", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(FMSTheme.textPrimary)
                    }
                }
            }
            .sheet(isPresented: $showSummary) {
                InspectionSummaryView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingExportSheet) {
                let data = viewModel.generateReport()
                if let url = saveReportToTemp(data: data, checklist: viewModel.checklist) {
                    ShareSheet(items: [url])
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                    animateCheckmark = true
                }
            }
        }
    }

    private func saveReportToTemp(data: Data, checklist: InspectionChecklist) -> URL? {
        let fileName = "FMS_Inspection_\(checklist.inspectionType.rawValue)_\(checklist.vehicleId)_\(formatFileDate()).txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: url)
        return url
    }

    private func formatFileDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmm"
        return f.string(from: Date())
    }
}

// MARK: - UIKit Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
