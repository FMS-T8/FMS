import SwiftUI
import PhotosUI

struct DriverProfileTab: View {
    @Bindable var viewModel: DriverDashboardViewModel
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(BannerManager.self) private var bannerManager
    
    @State private var securityVM = SecuritySettingsViewModel()
    @State private var showMFAEnrollment = false

    @State private var showDocumentPicker = false
    @State private var selectedDocType: DocumentType = .drivingLicense
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var documentLoadErrorMessage: String?
    @State private var selectedDocument: UploadedDocument?
    @State private var uploadedDocuments: [UploadedDocument] = [
        UploadedDocument(type: .drivingLicense, name: "Driving License", subtitle: "Valid until Oct 24, 2025", status: .verified),
        UploadedDocument(type: .governmentId, name: "Government ID Proof", subtitle: "Verified - SSN Attached", status: .verified),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                FMSTheme.backgroundPrimary.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        profileHeader
                        documentsSection
                        securitySection
                        vehicleCard
                        logoutButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                documentUploadSheet
            }
            .sheet(item: $selectedDocument) { doc in
                documentDetailSheet(doc: doc)
            }
            .sheet(isPresented: $showMFAEnrollment) {
                MFAEnrollmentView(vm: securityVM, bannerManager: bannerManager)
            }
            .task {
                await securityVM.loadSecurityState()
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
            Circle()
                .stroke(FMSTheme.amber.opacity(0.4), lineWidth: 2)
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 90))
                        .foregroundStyle(FMSTheme.textTertiary.opacity(0.5))
                )

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

    // MARK: - Documents Section

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Documents")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)

            ForEach(uploadedDocuments) { doc in
                Button {
                    selectedDocument = doc
                } label: {
                    documentCard(doc: doc)
                }
                .buttonStyle(.plain)
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

    private static let driverDocumentTypes: [DocumentType] = [.drivingLicense, .governmentId]

    private var availableDocumentTypes: [DocumentType] {
        Self.driverDocumentTypes.filter { type in
            !uploadedDocuments.contains(where: { $0.type == type && $0.status != .expired && $0.status != .rejected })
        }
    }

    private var documentUploadSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if availableDocumentTypes.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(FMSTheme.alertGreen)
                        Text("All Documents Uploaded")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(FMSTheme.textPrimary)
                        Text("All required documents have been added.")
                            .font(.system(size: 14))
                            .foregroundStyle(FMSTheme.textSecondary)
                    }
                    Spacer()
                } else {
                    Text("Select Document Type")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(FMSTheme.textPrimary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(availableDocumentTypes) { type in
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
                            Text("Choose Photo")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundStyle(FMSTheme.obsidian)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(FMSTheme.amber)
                        .cornerRadius(12)
                    }
                }

                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Upload Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showDocumentPicker = false }
                        .foregroundStyle(FMSTheme.textSecondary)
                }
            }
            .onAppear {
                // Auto-select first available type
                if let first = availableDocumentTypes.first {
                    selectedDocType = first
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(FMSTheme.backgroundPrimary)
        .alert("Unable to Upload Document", isPresented: documentLoadErrorPresented) {
            Button("OK", role: .cancel) {
                documentLoadErrorMessage = nil
            }
        } message: {
            Text(documentLoadErrorMessage ?? "Please try again.")
        }
    }

    // MARK: - Document Detail Sheet

    private func documentDetailSheet(doc: UploadedDocument) -> some View {
        NavigationStack {
            ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(FMSTheme.amber.opacity(0.12))
                        .frame(width: 80, height: 80)
                    Image(systemName: doc.type.icon)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(FMSTheme.amber)
                }

                Text(doc.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(FMSTheme.textPrimary)

                let details = documentDetails(for: doc.type)
                VStack(spacing: 0) {
                    ForEach(Array(details.enumerated()), id: \.offset) { index, detail in
                        HStack {
                            Text(detail.label)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(FMSTheme.textSecondary)
                            Spacer()
                            Text(detail.value)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(FMSTheme.textPrimary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)

                        if index != details.count - 1 {
                            Divider().background(FMSTheme.borderLight)
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .background(FMSTheme.cardBackground)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(FMSTheme.borderLight, lineWidth: 1)
                )

                HStack(spacing: 8) {
                    Image(systemName: doc.status.systemImage)
                        .foregroundStyle(doc.status.color)
                    Text(doc.status.label)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(doc.status.color)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(doc.status.color.opacity(0.12))
                .cornerRadius(10)

            }
            .padding(20)
            .padding(.top, 8)
            .frame(maxWidth: .infinity)
            }
            .navigationTitle(doc.type.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { selectedDocument = nil }
                        .foregroundStyle(FMSTheme.amber)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(FMSTheme.backgroundPrimary)
    }

    private func documentDetails(for type: DocumentType) -> [(label: String, value: String)] {
        switch type {
        case .drivingLicense:
            return [
                ("License No.", "DL-1420110012345"),
                ("Name", viewModel.driver.name),
                ("Date of Birth", "15 Mar 1990"),
                ("Valid From", "10 Oct 2020"),
                ("Valid Until", "24 Oct 2025"),
                ("Category", "LMV / Transport"),
            ]
        case .governmentId:
            return [
                ("Aadhaar No.", "XXXX-XXXX-1234"),
                ("Name", viewModel.driver.name),
                ("Verification", "Verified"),
                ("Issued By", "UIDAI"),
            ]
        case .vehicleRegistration:
            return [
                ("Reg. No.", viewModel.assignedVehicle?.plateNumber ?? "N/A"),
                ("Owner", "FMS Fleet Pvt. Ltd."),
                ("Valid Until", "Mar 2028"),
            ]
        case .insurance:
            return [
                ("Policy No.", "INS-2024-78432"),
                ("Provider", "ICICI Lombard"),
                ("Coverage", "Comprehensive"),
                ("Valid Until", "Dec 2025"),
            ]
        }
    }

    // MARK: - Security Section
    
    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Security")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(FMSTheme.textPrimary)
            
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Two-Factor Authentication")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(FMSTheme.textPrimary)
                        Text(securityVM.isTwoFactorEnabled ? "Active" : "Secure your account")
                            .font(.system(size: 12))
                            .foregroundStyle(securityVM.isTwoFactorEnabled ? FMSTheme.amber : FMSTheme.textTertiary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { securityVM.isTwoFactorEnabled },
                        set: { newValue in
                            if newValue {
                                Task {
                                    await securityVM.initiateMFAEnrollment()
                                    if securityVM.mfaEnrollmentResponse != nil {
                                        showMFAEnrollment = true
                                    } else {
                                        bannerManager.show(type: .error, message: securityVM.errorMessage ?? "Failed to start 2FA setup.")
                                    }
                                }
                            } else {
                                Task { await securityVM.unenrollAllMFAFactors(bannerManager: bannerManager) }
                            }
                        }
                    ))
                    .tint(FMSTheme.amber)
                }
            }
            .padding(14)
            .background(FMSTheme.cardBackground)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(FMSTheme.borderLight, lineWidth: 1)
            )
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
            Task { await authViewModel.logout() }
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
