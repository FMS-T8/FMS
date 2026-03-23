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
                            Text("Your vehicle status has been updated to \(Text(viewModel.vehicleStatus).fontWeight(.bold))\(viewModel.checklist.allPassed ? ". Have a safe trip!" : ". Please review flagged items.")")
                        } else {
                            Text("Post-trip inspection recorded. Vehicle status: \(Text(viewModel.vehicleStatus).fontWeight(.bold)). Thank you for completing your trip safely.")
                        }
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(FMSTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                }

                // Defects reported notification (FM-206)
                if viewModel.defectsCreatedCount > 0 || viewModel.defectsQueuedCount > 0 {
                    VStack(spacing: 6) {
                        if viewModel.defectsCreatedCount > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "wrench.and.screwdriver.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(FMSTheme.alertOrange)

                                Text("\(viewModel.defectsCreatedCount) defect\(viewModel.defectsCreatedCount == 1 ? "" : "s") reported to maintenance")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(FMSTheme.textPrimary)
                            }
                        }
                        if viewModel.defectsQueuedCount > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "wifi.slash")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(FMSTheme.alertOrange)

                                Text("\(viewModel.defectsQueuedCount) defect\(viewModel.defectsQueuedCount == 1 ? "" : "s") queued — will send when online")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(FMSTheme.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(FMSTheme.alertOrange.opacity(0.08))
                    .cornerRadius(10)
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
                            viewModel.prepareExport(includeTimestamp: true)
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
            .sheet(isPresented: exportSheetPresented) {
                if let url = viewModel.exportURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Export Failed", isPresented: exportErrorPresented) {
                Button("OK", role: .cancel) {
                    viewModel.clearExportError()
                }
            } message: {
                Text(viewModel.exportErrorMessage ?? "Unable to create an inspection report.")
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                    animateCheckmark = true
                }
            }
        }
    }

    private var exportSheetPresented: Binding<Bool> {
        Binding(
            get: { viewModel.showingExportSheet && viewModel.exportURL != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.clearExportState()
                }
            }
        )
    }

    private var exportErrorPresented: Binding<Bool> {
        Binding(
            get: { viewModel.exportErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.clearExportError()
                }
            }
        )
    }
}
