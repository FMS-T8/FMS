import SwiftUI
import PDFKit
import Supabase
import UniformTypeIdentifiers
import QuickLook

// MARK: - Document Slot Definition
struct DocumentSlot {
    let key: String
    let displayName: String
    let icon: String
}

let kDocumentSlots: [DocumentSlot] = [
    DocumentSlot(key: "puc",          displayName: "Pollution Certificate (PUC)", icon: "wind"),
    DocumentSlot(key: "permit",       displayName: "Permit",                       icon: "clipboard"),
    DocumentSlot(key: "insurance",    displayName: "Insurance",                    icon: "shield.lefthalf.filled"),
    DocumentSlot(key: "registration", displayName: "Registration Certificate (RC)", icon: "doc.plaintext"),
    DocumentSlot(key: "fitness",      displayName: "Fitness Certificate",           icon: "wrench.and.screwdriver")
]

// MARK: - VehicleDocumentsView (List Page)
public struct VehicleDocumentsView: View {
    let vehicleId: String
    let documents: [VehicleDocument]
    let isLoading: Bool
    let errorMessage: String?
    let onDocumentSaved: () -> Void

    public var body: some View {
        ZStack {
            FMSTheme.backgroundPrimary.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 12) {
                    if isLoading {
                        loadingRow
                    }
                    if let error = errorMessage {
                        errorRow(error)
                    }
                    ForEach(kDocumentSlots, id: \.key) { slot in
                        let doc = matchedDocument(for: slot)
                        NavigationLink {
                            VehicleDocumentDetailView(
                                vehicleId: vehicleId,
                                slot: slot,
                                document: doc,
                                onSave: onDocumentSaved
                            )
                        } label: {
                            DocumentRowCard(slot: slot, document: doc)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Vehicle Documents")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private var loadingRow: some View {
        HStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: FMSTheme.amber))
            Text("Updating documents…")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(FMSTheme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func errorRow(_ msg: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.system(size: 14))
            Text(msg)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.red)
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    /// Maps a slot key to the actual document_type value stored in the database.
    private func dbType(for slotKey: String) -> String {
        switch slotKey {
        case "puc":          return "pollution"
        case "registration": return "registration"
        case "permit":       return "permit"
        case "insurance":    return "insurance"
        case "fitness":      return "fitness"
        default:             return slotKey
        }
    }

    private func matchedDocument(for slot: DocumentSlot) -> VehicleDocument? {
        let expected = dbType(for: slot.key)
        return documents.first { $0.documentType.lowercased() == expected }
    }
}

// MARK: - Document Row Card
private struct DocumentRowCard: View {
    let slot: DocumentSlot
    let document: VehicleDocument?

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(statusColor)
                .frame(width: 5)
                .padding(.vertical, 10)

            ZStack {
                Circle()
                    .fill(FMSTheme.backgroundPrimary)
                    .frame(width: 44, height: 44)
                Image(systemName: slot.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(FMSTheme.textSecondary)
            }
            .padding(.leading, 14)

            VStack(alignment: .leading, spacing: 5) {
                Text(slot.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(FMSTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(statusLabel)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.14))
                        .cornerRadius(6)

                    if let expiry = document?.expiryDate {
                        Text("Expiry: \(expiry.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(FMSTheme.textSecondary)
                    } else if document == nil {
                        Text("Not uploaded")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(FMSTheme.textSecondary)
                    }
                }
            }
            .padding(.leading, 12)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(FMSTheme.textTertiary)
                .padding(.trailing, 14)
        }
        .padding(.vertical, 12)
        .background(FMSTheme.cardBackground)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
    }

    private var statusColor: Color {
        guard let doc = document else { return FMSTheme.textTertiary }
        switch doc.documentStatus {
        case .valid:        return .green
        case .expiringSoon: return .orange
        case .expired:      return .red
        }
    }

    private var statusLabel: String {
        guard let doc = document else { return "Missing" }
        switch doc.documentStatus {
        case .valid:        return "Valid"
        case .expiringSoon: return "Expiring Soon"
        case .expired:      return "Expired"
        }
    }
}

// MARK: - PDF Preview (UIViewRepresentable)
/// Handles both local file URLs and remote HTTPS URLs.
private struct PDFPreviewView: View {
    let url: URL
    @State private var pdfData: Data? = nil
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let data = pdfData, let doc = PDFDocument(data: data) {
                PDFKitView(document: doc)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(FMSTheme.amber)
                    Text("Unable to load preview")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(FMSTheme.textTertiary)
                }
            }
        }
        .task {
            await loadPDF()
        }
    }

    private func loadPDF() async {
        if url.isFileURL {
            pdfData = try? Data(contentsOf: url)
        } else {
            // Extract the storage path from the full public URL.
            // URL format: https://<id>.supabase.co/storage/v1/object/public/vehicle-documents/<path>
            let urlString = url.absoluteString
            let bucketName = "vehicle-documents"
            if let markerRange = urlString.range(of: "/\(bucketName)/") {
                let storagePath = String(urlString[markerRange.upperBound...])
                pdfData = try? await SupabaseService.shared.client.storage
                    .from(bucketName)
                    .download(path: storagePath)
            } else {
                // Fallback: direct URLSession (works if bucket is truly public)
                pdfData = try? await URLSession.shared.data(from: url).0
            }
        }
        isLoading = false
    }
}

private struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePage
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        view.document = document
        return view
    }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - Document Detail View
public struct VehicleDocumentDetailView: View {
    let vehicleId: String
    let slot: DocumentSlot
    let document: VehicleDocument?
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFileURL: URL? = nil
    @State private var showFileImporter = false
    @State private var isUploading = false
    @State private var uploadError: String? = nil
    
    @State private var quickLookURL: URL?
    @State private var isDownloadingForQuickLook = false
    @State private var isEditing = false
    
    @State private var field1 = ""
    @State private var field2 = ""
    @State private var issueDate = Date()
    @State private var expiryDate = Date().addingTimeInterval(365 * 24 * 3600)
    
    // Persistent ID for new documents to prevent orphaned storage files on retry
    @State private var pendingDocumentID: String? = nil

    private var hasFile: Bool {
        guard let url = document?.fileUrl, !url.isEmpty,
              URL(string: url) != nil else { return false }
        return true
    }

    public var body: some View {
        ZStack {
            FMSTheme.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // PDF Preview card
                    previewCard

                    // Type-specific detail fields
                    if document != nil && !isEditing {
                        detailFieldsCard
                    } else if selectedFileURL != nil || isEditing {
                        detailEntryForm
                        
                        if let error = uploadError {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 16)
                                .multilineTextAlignment(.center)
                        }
                        
                        saveButton
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 3) {
                    Text(slot.displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(FMSTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(statusLabel)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.15))
                        .cornerRadius(6)
                }
            }
            if document != nil && !isEditing {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        startEditing()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(FMSTheme.amber)
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                
                // CRITICAL: Stop access to any previously selected file before picking a new one
                selectedFileURL?.stopAccessingSecurityScopedResource()
                
                if url.startAccessingSecurityScopedResource() {
                    selectedFileURL = url
                    
                    if document == nil && pendingDocumentID == nil {
                        pendingDocumentID = UUID().uuidString.lowercased()
                    }
                }
            case .failure(let error):
                print("Failed to pick file: \(error)")
            }
        }
        .quickLookPreview($quickLookURL)
        .onDisappear {
            selectedFileURL?.stopAccessingSecurityScopedResource()
        }
    }

    // MARK: Status badge in navbar
    private var statusBadge: some View {
        Text(statusLabel)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.15))
            .cornerRadius(8)
    }

    // MARK: PDF Preview Card
    @ViewBuilder
    private var previewCard: some View {
        let hasPreviewable = hasFile || selectedFileURL != nil

        let card = RoundedRectangle(cornerRadius: 16)
            .fill(FMSTheme.cardBackground)
            .frame(height: 240)
            .overlay {
                if let url = selectedFileURL {
                    // 1. Show newly selected file (replacement or first-time)
                    PDFPreviewView(url: url)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 13, weight: .semibold))
                                .padding(6)
                                .background(.ultraThinMaterial, in: Circle())
                                .padding(8)
                        }
                        .overlay(alignment: .topTrailing) {
                            Button {
                                url.stopAccessingSecurityScopedResource()
                                selectedFileURL = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            .padding(8)
                        }
                } else if hasFile, let urlStr = document?.fileUrl,
                          let url = URL(string: urlStr) {
                    // 2. Show existing file
                    PDFPreviewView(url: url)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(alignment: .bottomTrailing) {
                            if isEditing {
                                Button {
                                    showFileImporter = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("Replace")
                                    }
                                    .font(.system(size: 13, weight: .bold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(20)
                                    .foregroundColor(FMSTheme.textPrimary)
                                }
                                .padding(8)
                            } else {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .padding(6)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .padding(8)
                            }
                        }
                } else {
                    // No file yet — show placeholder
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(FMSTheme.amber)
                        Text("No document uploaded")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(FMSTheme.textTertiary)
                            
                        Button {
                            showFileImporter = true
                        } label: {
                            Text("Select PDF to Upload")
                                .font(.system(size: 14, weight: .bold))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(FMSTheme.amber.opacity(0.1))
                                .foregroundColor(FMSTheme.amber)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)

        if hasPreviewable {
            card
                .onTapGesture {
                    if let url = selectedFileURL {
                        quickLookURL = url
                    } else if hasFile, let urlStr = document?.fileUrl, let url = URL(string: urlStr) {
                        downloadAndShowQuickLook(url: url)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 16))
                .overlay {
                    if isDownloadingForQuickLook {
                        ZStack {
                            Color.black.opacity(0.4)
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.5)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
        } else {
            card
        }
    }

    private func downloadAndShowQuickLook(url: URL) {
        if isDownloadingForQuickLook { return }
        isDownloadingForQuickLook = true
        Task {
            let urlString = url.absoluteString
            let bucketName = "vehicle-documents"
            var dataToSave: Data? = nil
            
            if let markerRange = urlString.range(of: "/\(bucketName)/") {
                let path = String(urlString[markerRange.upperBound...])
                dataToSave = try? await SupabaseService.shared.client.storage
                    .from(bucketName)
                    .download(path: path)
            } else {
                dataToSave = try? await URLSession.shared.data(from: url).0
            }
            
            if let data = dataToSave {
                let fileName = url.lastPathComponent.hasSuffix(".pdf") ? url.lastPathComponent : "document.pdf"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                do {
                    try data.write(to: tempURL, options: .atomic)
                    await MainActor.run {
                        self.quickLookURL = tempURL
                        self.isDownloadingForQuickLook = false
                    }
                } catch {
                    print("Failed to save temporary PDF: \(error)")
                    await MainActor.run { self.isDownloadingForQuickLook = false }
                }
            } else {
                await MainActor.run { self.isDownloadingForQuickLook = false }
            }
        }
    }

    // MARK: Detail Fields Card
    @ViewBuilder
    private var detailFieldsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(fields, id: \.label) { field in
                VStack(alignment: .leading, spacing: 4) {
                    Text(field.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(FMSTheme.textTertiary)
                    Text(field.value.isEmpty ? "—" : field.value)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(FMSTheme.textPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                if field.label != fields.last?.label {
                    Divider()
                        .overlay(FMSTheme.borderLight)
                        .padding(.horizontal, 16)
                }
            }
        }
        .background(FMSTheme.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
    
    // MARK: Manual Entry Form
    @ViewBuilder
    private var detailEntryForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Document Details")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(FMSTheme.textPrimary)
            
            if slot.key == "insurance" {
                entryTextField("Insurance Company", text: $field1)
                entryTextField("Policy Number", text: $field2)
                entryDatePicker("Expiry Date", selection: $expiryDate)
            } else if slot.key.contains("registration") {
                entryTextField("Owner Name", text: $field1)
                entryTextField("Vehicle Model", text: $field2)
                entryDatePicker("Registration Date", selection: $issueDate)
            } else if slot.key == "permit" {
                entryTextField("Permit Number", text: $field1)
                entryTextField("Permit Type", text: $field2)
                entryDatePicker("Expiry Date", selection: $expiryDate)
            } else {
                // PUC & Fitness
                entryTextField("Certificate Number", text: $field1)
                entryDatePicker("Issue Date", selection: $issueDate)
                entryDatePicker("Expiry Date", selection: $expiryDate)
            }
        }
        .padding(16)
        .background(FMSTheme.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
    }

    private func entryTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .padding(14)
            .background(FMSTheme.backgroundPrimary)
            .foregroundColor(FMSTheme.textPrimary)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(FMSTheme.borderLight, lineWidth: 1))
            .font(.system(size: 15, weight: .medium))
    }

    private func entryDatePicker(_ title: String, selection: Binding<Date>) -> some View {
        DatePicker(title, selection: selection, displayedComponents: .date)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(FMSTheme.textSecondary)
    }
    
    // MARK: Save Button
    @ViewBuilder
    private var saveButton: some View {
        Button {
            uploadAndSave()
        } label: {
            HStack(spacing: 8) {
                if isUploading {
                    ProgressView().tint(.white)
                }
                Text(isUploading ? "Uploading..." : "Save Document")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(FMSTheme.obsidian)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(FMSTheme.amber)
            .cornerRadius(12)
        }
        .disabled(isUploading || field1.isEmpty)
        .opacity((isUploading || field1.isEmpty) ? 0.6 : 1.0)
    }

    // MARK: Save Logic
    private func uploadAndSave() {
        guard selectedFileURL != nil || isEditing else { return }
        isUploading = true
        uploadError = nil
        
        Task {
            do {
                var publicUrlStr = document?.fileUrl ?? ""
                let docID = document?.id ?? pendingDocumentID ?? UUID().uuidString.lowercased()
                
                if let url = selectedFileURL {
                    // Read data then stop access ONLY AFTER success to allow retries
                    let data = try? Data(contentsOf: url)
                    
                    guard let fileData = data else {
                        throw NSError(domain: "FMS", code: 400, userInfo: [NSLocalizedDescriptionKey: "Could not read selected file"])
                    }
                    
                    let fileName = "\(vehicleId)_\(slot.key)_\(docID.prefix(8)).pdf"
                    
                    try await SupabaseService.shared.client.storage
                        .from("vehicle-documents")
                        .upload(
                            fileName,
                            data: fileData,
                            options: FileOptions(contentType: "application/pdf", upsert: true)
                        )
                    
                    // Get Public URL
                    let publicUrl = try SupabaseService.shared.client.storage
                        .from("vehicle-documents")
                        .getPublicURL(path: fileName)
                    publicUrlStr = publicUrl.absoluteString
                }
                
                // Get current user for uploadedBy
                let session = try await SupabaseService.shared.client.auth.session
                let userId = session.user.id.uuidString
                
                // DB schema stores extra fields in a metadata jsonb column.
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let expiryDateString = dateFormatter.string(from: expiryDate)

                struct DocumentInsertPayload: Encodable {
                    let id: String
                    let vehicle_id: String
                    let document_type: String
                    let file_url: String
                    let expiry_date: String?
                    let uploaded_by: String
                    let metadata: [String: String]?
                }

                // Map slot.key to the value allowed by the DB CHECK constraint.
                let mappedType: String
                var metaDict: [String: String] = [:]

                if slot.key == "puc" {
                    mappedType = "pollution"
                    if !field1.isEmpty { metaDict["certificate_number"] = field1 }
                    metaDict["issue_date"] = dateFormatter.string(from: issueDate)
                } else if slot.key == "registration" {
                    mappedType = "registration"
                    if !field1.isEmpty { metaDict["owner_name"] = field1 }
                    if !field2.isEmpty { metaDict["vehicle_model"] = field2 }
                    metaDict["registration_date"] = dateFormatter.string(from: issueDate)
                } else if slot.key == "insurance" {
                    mappedType = "insurance"
                    if !field1.isEmpty { metaDict["insurance_company"] = field1 }
                    if !field2.isEmpty { metaDict["policy_number"] = field2 }
                } else if slot.key == "permit" {
                    mappedType = "permit"
                    if !field1.isEmpty { metaDict["permit_number"] = field1 }
                    if !field2.isEmpty { metaDict["permit_type"] = field2 }
                } else {
                    // fitness
                    mappedType = slot.key
                    if !field1.isEmpty { metaDict["certificate_number"] = field1 }
                    metaDict["issue_date"] = dateFormatter.string(from: issueDate)
                }

                let insertPayload = DocumentInsertPayload(
                    id: docID,
                    vehicle_id: vehicleId,
                    document_type: mappedType,
                    file_url: publicUrlStr,
                    expiry_date: slot.key == "registration" ? nil : expiryDateString,
                    uploaded_by: userId.lowercased(),
                    metadata: metaDict.isEmpty ? nil : metaDict
                )

                // Insert or Update into Database
                try await SupabaseService.shared.client
                    .from("vehicle_documents")
                    .upsert(insertPayload)
                    .execute()
                
                await MainActor.run {
                    selectedFileURL?.stopAccessingSecurityScopedResource()
                    selectedFileURL = nil
                    isUploading = false
                    onSave()
                    dismiss()
                }
            } catch {
                #if DEBUG
                print("🚨 Document save failed: \(error.localizedDescription)")
                #endif
                
                await MainActor.run {
                    isUploading = false
                    // Show a helpful, generic message to the user
                    self.uploadError = "Unable to save document. Please check your connection and try again."
                }
            }
        }
    }

    // MARK: Type-specific fields
    private var fields: [DetailField] {
        guard let doc = document else { return [] }
        let key = slot.key

        if key == "insurance" {
            return [
                DetailField(label: "Insurance Company", value: doc.insuranceCompany ?? ""),
                DetailField(label: "Policy Number",     value: doc.policyNumber ?? ""),
                DetailField(label: "Expiry Date",       value: formatted(doc.expiryDate)),
                DetailField(label: "Status",            value: statusLabel)
            ]
        } else if key.contains("registration") {
            return [
                DetailField(label: "Owner Name",        value: doc.ownerName ?? ""),
                DetailField(label: "Vehicle Model",     value: doc.vehicleModel ?? ""),
                DetailField(label: "Registration Date", value: formatted(doc.registrationDate))
            ]
        } else if key == "permit" {
            return [
                DetailField(label: "Permit Number",     value: doc.permitNumber ?? ""),
                DetailField(label: "Permit Type",       value: doc.permitType ?? ""),
                DetailField(label: "Expiry Date",       value: formatted(doc.expiryDate))
            ]
        } else {
            // PUC & Fitness
            return [
                DetailField(label: "Certificate Number", value: doc.certificateNumber ?? ""),
                DetailField(label: "Issue Date",         value: formatted(doc.issueDate)),
                DetailField(label: "Expiry Date",        value: formatted(doc.expiryDate))
            ]
        }
    }

    private func formatted(_ date: Date?) -> String {
        guard let date else { return "" }
        return date.formatted(date: .long, time: .omitted)
    }

    // MARK: Helpers
    private func startEditing() {
        guard let doc = document else { return }
        isEditing = true
        
        let key = slot.key
        if key == "insurance" {
            field1 = doc.insuranceCompany ?? ""
            field2 = doc.policyNumber ?? ""
        } else if key.contains("registration") {
            field1 = doc.ownerName ?? ""
            field2 = doc.vehicleModel ?? ""
            if let d = doc.registrationDate { issueDate = d }
        } else if key == "permit" {
            field1 = doc.permitNumber ?? ""
            field2 = doc.permitType ?? ""
        } else {
            // PUC & Fitness
            field1 = doc.certificateNumber ?? ""
            if let d = doc.issueDate { issueDate = d }
        }
        if let d = doc.expiryDate { expiryDate = d }
    }

    private var statusColor: Color {
        guard let doc = document else { return FMSTheme.textTertiary }
        switch doc.documentStatus {
        case .valid:        return .green
        case .expiringSoon: return .orange
        case .expired:      return .red
        }
    }

    private var statusLabel: String {
        guard let doc = document else { return "Missing" }
        switch doc.documentStatus {
        case .valid:        return "Valid"
        case .expiringSoon: return "Expiring Soon"
        case .expired:      return "Expired"
        }
    }
}

// MARK: - Simple field model
private struct DetailField {
    let label: String
    let value: String
}

// MARK: - DocumentStatus enum
public enum DocumentStatus {
    case valid, expiringSoon, expired
}

// MARK: - VehicleDocument extension
extension VehicleDocument {
    public var documentStatus: DocumentStatus {
        guard let expiry = expiryDate else { return .valid }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let expiryDay = calendar.startOfDay(for: expiry)
        
        if expiryDay < today { return .expired }
        let daysLeft = calendar.dateComponents([.day], from: today, to: expiryDay).day ?? 0
        return daysLeft <= 30 ? .expiringSoon : .valid
    }
}
