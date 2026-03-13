import SwiftUI
import PhotosUI

struct DriverProfileTab: View {
    @Bindable var viewModel: DriverDashboardViewModel
    @Environment(AuthViewModel.self) private var authViewModel

    @State private var showDocumentPicker = false
    @State private var selectedDocType: DocumentType = .drivingLicense
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var documentLoadErrorMessage: String?
    @State private var uploadedDocuments: [UploadedDocument] = [
        UploadedDocument(type: .drivingLicense, name: "Driving License", subtitle: "Expires Oct 24, 2025", status: .active),
        UploadedDocument(type: .governmentId, name: "Government ID Proof", subtitle: "Verified - SSN Attached", status: .verified),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeader
                    editProfileButton
                    documentsSection
                    vehicleCard
                    logoutButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(FMSTheme.backgroundPrimary)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {} label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(FMSTheme.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                documentUploadSheet
            }
            .onChange(of: selectedPhoto) { _, newValue in
                guard let item = newValue else { return }
                let selectedType = selectedDocType
                Task {
                    do {
                        guard try await item.loadTransferable(type: Data.self) != nil else {
                            await MainActor.run {
                                documentLoadErrorMessage = "The selected document could not be loaded. Please choose another file."
                                selectedPhoto = nil
                                showDocumentPicker = true
                            }
                            return
                        }

                        let doc = UploadedDocument(
                            type: selectedType,
                            name: selectedType.displayName,
                            subtitle: "Uploaded just now",
                            status: .pending
                        )

                        await MainActor.run {
                            uploadedDocuments.append(doc)
                            documentLoadErrorMessage = nil
                            selectedPhoto = nil
                            showDocumentPicker = false
                        }
                    } catch {
                        await MainActor.run {
                            documentLoadErrorMessage = "Failed to load the selected document. Please try again."
                            selectedPhoto = nil
                            showDocumentPicker = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .stroke(FMSTheme.amber.opacity(0.4), lineWidth: 2)
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 90))
                            .foregroundStyle(FMSTheme.textTertiary.opacity(0.5))
                    )

                ZStack {
                    Circle()
                        .fill(FMSTheme.cardBackground)
                        .frame(width: 28, height: 28)
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(FMSTheme.amber)
                }
                .offset(x: 2, y: 2)
            }

            Text(viewModel.driver.name)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)

            if let phone = viewModel.driver.phone {
                Text(phone)
                    .font(.system(size: 14))
                    .foregroundStyle(FMSTheme.textSecondary)
            }

            Text("LICENSE: \(viewModel.driver.employeeID)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(FMSTheme.textTertiary)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Edit Profile Button

    private var editProfileButton: some View {
        Button {} label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 14, weight: .semibold))
                Text("Edit Profile")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(FMSTheme.obsidian)
            .frame(maxWidth: 200)
            .padding(.vertical, 12)
            .background(FMSTheme.amber)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Documents Section

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Documents")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(FMSTheme.textPrimary)

                Spacer()

                Button("View All") {}
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FMSTheme.amber)
            }

            ForEach(uploadedDocuments) { doc in
                documentCard(doc: doc)
            }

            // Upload button
            Button {
                showDocumentPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                    Text("Upload New Document")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(FMSTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(FMSTheme.cardBackground)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(FMSTheme.borderLight, style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func documentCard(doc: UploadedDocument) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(FMSTheme.amber.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: doc.type.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(FMSTheme.amber)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(doc.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FMSTheme.textPrimary)
                Text(doc.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(FMSTheme.textSecondary)
            }

            Spacer()

            Text(doc.status.label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(doc.status.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(doc.status.color.opacity(0.12))
                .cornerRadius(5)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FMSTheme.textTertiary)
        }
        .padding(14)
        .background(FMSTheme.cardBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(doc.type == .drivingLicense ? Color.blue.opacity(0.3) : FMSTheme.borderLight,
                        lineWidth: doc.type == .drivingLicense ? 1.5 : 1)
        )
    }

    // MARK: - Document Upload Sheet

    private var documentUploadSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Select Document Type")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(FMSTheme.textPrimary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(DocumentType.allCases) { type in
                        let isSelected = selectedDocType == type
                        Button {
                            selectedDocType = type
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 24, weight: .semibold))
                                Text(type.displayName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .multilineTextAlignment(.center)
                            }
                            .foregroundStyle(isSelected ? FMSTheme.obsidian : FMSTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(isSelected ? FMSTheme.amber : FMSTheme.cardBackground)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(isSelected ? Color.clear : FMSTheme.borderLight, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Choose File")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(FMSTheme.obsidian)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(FMSTheme.amber)
                    .cornerRadius(12)
                }

                Spacer()
            }
            .padding(20)
            .background(FMSTheme.backgroundPrimary)
            .navigationTitle("Upload Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showDocumentPicker = false }
                        .foregroundStyle(FMSTheme.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
        .alert("Unable to Upload Document", isPresented: documentLoadErrorPresented) {
            Button("OK", role: .cancel) {
                documentLoadErrorMessage = nil
            }
        } message: {
            Text(documentLoadErrorMessage ?? "Please try again.")
        }
    }

    // MARK: - Vehicle Card

    private var vehicleCard: some View {
        Group {
            if let vehicle = viewModel.assignedVehicle {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 40/255, green: 40/255, blue: 45/255),
                                    Color(red: 30/255, green: 30/255, blue: 35/255)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CURRENT VEHICLE")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(FMSTheme.amber)
                                .tracking(1)

                            if let name = [vehicle.manufacturer, vehicle.model].compactMap({ $0 }).joined(separator: " ") as String?,
                               !name.trimmingCharacters(in: .whitespaces).isEmpty {
                                Text(name)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.white)
                            }

                            Text("Plate: \(vehicle.plateNumber)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        Spacer()

                        Image(systemName: "truck.box.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.white.opacity(0.15))
                    }
                    .padding(20)
                }
                .frame(height: 130)
            }
        }
    }

    // MARK: - Logout

    private var logoutButton: some View {
        Button {
            withAnimation { authViewModel.logout() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                Text("Logout")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(FMSTheme.alertRed)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(FMSTheme.alertRed.opacity(0.08))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(FMSTheme.alertRed.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private extension DriverProfileTab {
    var documentLoadErrorPresented: Binding<Bool> {
        Binding(
            get: { documentLoadErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    documentLoadErrorMessage = nil
                }
            }
        )
    }
}
