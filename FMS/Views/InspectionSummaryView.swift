import SwiftUI

public struct InspectionSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: InspectionViewModel

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Report header
                    reportHeader

                    // Status badge
                    statusBadge

                    // Items breakdown
                    itemsSection

                    // Export button
                    exportButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(FMSTheme.backgroundPrimary)
            .navigationTitle("Inspection Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FMSTheme.amber)
                }
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
        }
    }

    // MARK: - Report Header

    private var reportHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(FMSTheme.amber)
                Text("\(viewModel.checklist.inspectionType.rawValue) Inspection Report")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(FMSTheme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                detailRow(label: "Vehicle", value: viewModel.checklist.vehicleId)
                detailRow(label: "Driver", value: viewModel.checklist.driverId)
                detailRow(label: "Date", value: viewModel.formattedDate(viewModel.checklist.createdAt))
                if let completed = viewModel.checklist.completedAt {
                    detailRow(label: "Completed", value: viewModel.formattedDate(completed))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FMSTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(FMSTheme.borderLight, lineWidth: 1)
            )
        }
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: viewModel.checklist.allPassed ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundStyle(viewModel.checklist.allPassed ? FMSTheme.alertGreen : FMSTheme.alertOrange)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.vehicleStatus)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(FMSTheme.textPrimary)
                Text("\(viewModel.checklist.completedCount)/\(viewModel.checklist.totalCount) items passed")
                    .font(.system(size: 13))
                    .foregroundStyle(FMSTheme.textSecondary)
            }

            Spacer()

            // Progress ring
            ZStack {
                Circle()
                    .stroke(FMSTheme.borderLight, lineWidth: 4)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: viewModel.checklist.progress)
                    .stroke(viewModel.checklist.allPassed ? FMSTheme.alertGreen : FMSTheme.amber, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                Text("\(Int(viewModel.checklist.progress * 100))%")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(FMSTheme.textPrimary)
            }
        }
        .padding(14)
        .background(FMSTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(FMSTheme.borderLight, lineWidth: 1)
        )
    }

    // MARK: - Items Section

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Item Details")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)

            ForEach(viewModel.checklist.items) { item in
                summaryItemRow(item: item)
            }
        }
    }

    private func summaryItemRow(item: InspectionItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: item.category.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(item.passed ? FMSTheme.alertGreen : FMSTheme.alertRed)

                Text(item.category.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FMSTheme.textPrimary)

                Spacer()

                Text(item.passed ? "PASS" : "FAIL")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(item.passed ? FMSTheme.alertGreen : FMSTheme.alertRed)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background((item.passed ? FMSTheme.alertGreen : FMSTheme.alertRed).opacity(0.1))
                    .cornerRadius(6)
            }

            if !item.notes.isEmpty {
                Text(item.notes)
                    .font(.system(size: 13))
                    .foregroundStyle(FMSTheme.textSecondary)
                    .padding(.leading, 24)
            }

            if item.photoData != nil {
                HStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 11))
                    Text("Photo attached")
                        .font(.system(size: 12))
                }
                .foregroundStyle(FMSTheme.textTertiary)
                .padding(.leading, 24)
            }
        }
        .padding(14)
        .background(FMSTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(item.passed ? FMSTheme.borderLight : FMSTheme.alertRed.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Export Button

    private var exportButton: some View {
        Button {
            viewModel.prepareExport(includeTimestamp: false)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                Text("Export Report")
                    .font(.headline.weight(.bold))
            }
        }
        .buttonStyle(.fmsPrimary)
        .padding(.bottom, 24)
    }

    // MARK: - Helpers

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(FMSTheme.textSecondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(FMSTheme.textPrimary)
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
