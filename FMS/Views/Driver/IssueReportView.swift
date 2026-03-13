import SwiftUI
import PhotosUI

struct IssueReportView: View {
    @Bindable var viewModel: DriverDashboardViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(BannerManager.self) private var bannerManager

    @State private var selectedCategory: IssueCategory = .engine
    @State private var selectedSeverity: IssueSeverity = .medium
    @State private var issueDescription: String = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoData: [Data] = []
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    categorySection
                    severitySection
                    descriptionSection
                    photoSection
                    submitButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(FMSTheme.backgroundPrimary)
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(FMSTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - Category

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(IssueCategory.allCases) { category in
                    let isSelected = selectedCategory == category

                    Button {
                        selectedCategory = category
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .font(.system(size: 20, weight: .semibold))
                            Text(category.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(isSelected ? FMSTheme.obsidian : FMSTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isSelected ? FMSTheme.amber : FMSTheme.cardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? Color.clear : FMSTheme.borderLight, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Severity

    private var severitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Severity")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)

            HStack(spacing: 8) {
                ForEach(IssueSeverity.allCases) { severity in
                    let isSelected = selectedSeverity == severity

                    Button {
                        selectedSeverity = severity
                    } label: {
                        Text(severity.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isSelected ? .white : severity.color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isSelected ? severity.color : severity.color.opacity(0.12))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Description")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)

            TextField("Describe the issue in detail...", text: $issueDescription, axis: .vertical)
                .font(.system(size: 14))
                .lineLimit(4...8)
                .padding(14)
                .background(FMSTheme.cardBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(FMSTheme.borderLight, lineWidth: 1)
                )
        }
    }

    // MARK: - Photos

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photos")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)

            if !photoData.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(photoData.indices, id: \.self) { index in
                            if let uiImage = UIImage(data: photoData[index]) {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))

                                    Button {
                                        photoData.remove(at: index)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(4)
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Circle())
                                    }
                                    .padding(4)
                                }
                            }
                        }
                    }
                }
            }

            PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 5, matching: .images) {
                Label("Add Photos", systemImage: "camera.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FMSTheme.amber)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(FMSTheme.amber.opacity(0.12))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(FMSTheme.amber.opacity(0.3), lineWidth: 1)
                    )
            }
            .onChange(of: selectedPhotos) { _, newItems in
                Task {
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            photoData.append(data)
                        }
                    }
                    selectedPhotos = []
                }
            }
        }
    }

    // MARK: - Submit

    private var submitButton: some View {
        Button {
            submitReport()
        } label: {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView()
                        .tint(FMSTheme.obsidian)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .bold))
                }
                Text("Submit Report")
                    .font(.headline.weight(.bold))
            }
        }
        .buttonStyle(.fmsPrimary)
        .disabled(issueDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
        .opacity(issueDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)
    }

    // MARK: - Submit Logic

    private func submitReport() {
        isSubmitting = true

        let report = IssueReport(
            driverId: viewModel.driver.id,
            vehicleId: viewModel.assignedVehicle?.id,
            tripId: viewModel.activeTrip?.id,
            category: selectedCategory,
            description: issueDescription,
            severity: selectedSeverity,
            photoData: photoData.isEmpty ? nil : photoData
        )

        viewModel.submitIssueReport(report)
        bannerManager.show(type: .success, message: "Issue report submitted successfully")
        dismiss()
    }
}
