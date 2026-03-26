//
//  VehicleBulkImportView.swift
//  FMS
//
//  Created by Anish on 26/03/26.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - CSV Template Document
struct CSVTemplateDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    static var writableContentTypes: [UTType] { [.commaSeparatedText] }
    
    var text: String

    init(text: String = "plate_number,chassis_number,purchase_date,odometer,manufacturer,model,fuel_type,fuel_tank_capacity,carrying_capacity\n") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let string = String(data: data, encoding: .utf8) {
            text = string
        } else {
            throw CocoaError(.fileReadUnknown)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return .init(regularFileWithContents: data)
    }
}

// MARK: - Main View
public struct VehicleBulkImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BannerManager.self) private var bannerManager
    
    @State private var viewModel = VehicleBulkImportViewModel()
    @State private var showingFilePicker = false
    @State private var showingExporter = false
    @State private var templateDocument = CSVTemplateDocument()
    
    public var onImportComplete: (() -> Void)?
    
    public init(onImportComplete: (() -> Void)? = nil) {
        self.onImportComplete = onImportComplete
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.parsedVehicles.isEmpty && !viewModel.isParsing {
                    instructionState
                } else if viewModel.isParsing {
                    ProgressView("Parsing CSV...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    previewState
                }
            }
            .background(FMSTheme.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Bulk Import Vehicles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(FMSTheme.textSecondary)
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        do {
                            try viewModel.processCSV(at: url)
                        } catch {
                            bannerManager.show(type: .error, message: error.localizedDescription)
                        }
                    }
                case .failure(let error):
                    bannerManager.show(type: .error, message: error.localizedDescription)
                }
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: templateDocument,
                contentType: .commaSeparatedText,
                defaultFilename: "Vehicle_Import_Template.csv"
            ) { result in
                if case .failure(let error) = result {
                    bannerManager.show(type: .error, message: "Failed to save template: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Instruction State
    private var instructionState: some View {
        VStack(spacing: 36) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(FMSTheme.amber.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: "list.bullet.clipboard.fill")
                    .font(.system(size: 44))
                    .foregroundColor(FMSTheme.amber)
            }
            
            VStack(spacing: 12) {
                Text("Import Your Fleet")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(FMSTheme.textPrimary)
                
                Text("Follow these simple steps to bulk add vehicles to your system without manual entry.")
                    .font(.system(size: 15))
                    .foregroundColor(FMSTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            VStack(alignment: .leading, spacing: 20) {
                instructionRow(number: "1", title: "Download Template", desc: "Get the pre-formatted CSV file")
                instructionRow(number: "2", title: "Add Your Data", desc: "Fill in plate numbers, models, etc")
                instructionRow(number: "3", title: "Upload & Verify", desc: "Select the file below to review")
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            Spacer()
            
            VStack(spacing: 16) {
                Button {
                    showingExporter = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("Download Blank Template")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(FMSTheme.amber)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(FMSTheme.amber.opacity(0.15))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(FMSTheme.amber.opacity(0.3), lineWidth: 1)
                    )
                }
                
                Button {
                    showingFilePicker = true
                } label: {
                    HStack {
                        Image(systemName: "folder.fill")
                        Text("Select Completed CSV")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(FMSTheme.obsidian)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(FMSTheme.amber)
                    .cornerRadius(14)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
    
    private func instructionRow(number: String, title: String, desc: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(FMSTheme.cardBackground)
                    .frame(width: 32, height: 32)
                    .overlay(Circle().stroke(FMSTheme.borderLight, lineWidth: 1))
                Text(number)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(FMSTheme.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(FMSTheme.textPrimary)
                Text(desc)
                    .font(.system(size: 13))
                    .foregroundColor(FMSTheme.textSecondary)
            }
        }
    }
    
    // MARK: - Preview State (Isolated Cards)
    private var previewState: some View {
        VStack(spacing: 0) {
            // Summary Banner
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Review Data")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(FMSTheme.textPrimary)
                    Text("Existing plate numbers will be skipped automatically.")
                        .font(.system(size: 13))
                        .foregroundColor(FMSTheme.textSecondary)
                }
                Spacer()
            }
            .padding(20)
            .background(FMSTheme.cardBackground)
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 16) {
                    let indices = viewModel.parsedVehicles.indices
                    ForEach(Array(indices), id: \.self) { index in
                        vehicleCard(index: index)
                    }
                }
                .padding(20)
            }
            .background(FMSTheme.backgroundPrimary)
            
            // Confirm Button
            VStack {
                Button {
                    if viewModel.hasValidationErrors {
                        bannerManager.show(type: .error, message: "Cannot import. Please fill in all required fields marked in red.")
                    } else if viewModel.parsedVehicles.isEmpty {
                        bannerManager.show(type: .warning, message: "No vehicles to import.")
                    } else {
                        Task {
                            do {
                                let result = try await viewModel.uploadVehicles()
                                
                                if result.inserted > 0 && result.skipped > 0 {
                                    bannerManager.show(type: .success, message: "Added \(result.inserted) new vehicles. Skipped \(result.skipped) already existing.")
                                } else if result.inserted > 0 {
                                    bannerManager.show(type: .success, message: "Successfully imported all \(result.inserted) vehicles.")
                                } else if result.skipped > 0 {
                                    bannerManager.show(type: .warning, message: "No new vehicles added. All \(result.skipped) vehicles already exist in the system.")
                                }
                                
                                onImportComplete?()
                                dismiss()
                            } catch {
                                bannerManager.show(type: .error, message: "Import failed: \(error.localizedDescription)")
                            }
                        }
                    }
                } label: {
                    HStack {
                        if viewModel.isUploading {
                            ProgressView().tint(FMSTheme.obsidian)
                        } else {
                            Image(systemName: "icloud.and.arrow.up.fill")
                            Text("Confirm & Upload (\(viewModel.parsedVehicles.count))")
                                .fontWeight(.bold)
                        }
                    }
                    .foregroundColor(FMSTheme.obsidian)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(viewModel.hasValidationErrors || viewModel.parsedVehicles.isEmpty ? FMSTheme.amber.opacity(0.5) : FMSTheme.amber)
                    .cornerRadius(14)
                }
                .disabled(viewModel.isUploading || viewModel.parsedVehicles.isEmpty)
                .padding()
            }
            .background(FMSTheme.backgroundPrimary)
            .overlay(Divider(), alignment: .top)
        }
    }

    // MARK: - Vehicle Card
    @ViewBuilder
    private func vehicleCard(index: Int) -> some View {
        // Guard against out-of-bounds during animated deletion
        if index < viewModel.parsedVehicles.count {
            VStack(alignment: .leading, spacing: 0) {

                // Card Header
                HStack {
                    Text("Vehicle Entry \(index + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(FMSTheme.textSecondary)
                        .textCase(.uppercase)
                        .tracking(1)

                    Spacer()

                    Button {
                        withAnimation {
                            // FIXED: Add `_ = ` to discard the result and resolve Swift's closure ambiguity
                            _ = viewModel.parsedVehicles.remove(at: index)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(FMSTheme.alertRed.opacity(0.8))
                            .padding(6)
                            .background(FMSTheme.alertRed.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider().background(FMSTheme.borderLight)

                // Editable Fields
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        labeledField(title: "Plate Number *",  text: $viewModel.parsedVehicles[index].plate_number)
                        labeledField(title: "Chassis Number *", text: $viewModel.parsedVehicles[index].chassis_number)
                    }
                    HStack(spacing: 12) {
                        labeledField(title: "Purchase Date *", text: $viewModel.parsedVehicles[index].purchase_date)
                        labeledField(title: "Odometer *",      text: $viewModel.parsedVehicles[index].odometer, keyboardType: .decimalPad)
                    }
                    HStack(spacing: 12) {
                        labeledField(title: "Make (Opt)",  text: $viewModel.parsedVehicles[index].manufacturer, isRequired: false)
                        labeledField(title: "Model (Opt)", text: $viewModel.parsedVehicles[index].model,        isRequired: false)
                        labeledField(title: "Type (Opt)",  text: $viewModel.parsedVehicles[index].fuel_type,    isRequired: false)
                    }
                }
                .padding(16)
            }
            .background(FMSTheme.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(FMSTheme.borderLight, lineWidth: 1)
            )
            .shadow(color: FMSTheme.shadowSmall.opacity(0.5), radius: 5, x: 0, y: 2)
        }
    }

    // MARK: - Reusable UI component for Structured Fields
    @ViewBuilder
    private func labeledField(title: String, text: Binding<String>, isRequired: Bool = true, keyboardType: UIKeyboardType = .default) -> some View {
        let isError = isRequired && text.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty
        
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isError ? FMSTheme.alertRed : FMSTheme.textSecondary)
                .textCase(.uppercase)
            
            TextField(isRequired ? "Required" : "Blank", text: text)
                .keyboardType(keyboardType)
                .font(.system(size: 15, weight: isRequired ? .semibold : .regular))
                .foregroundColor(FMSTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(isError ? FMSTheme.alertRed.opacity(0.08) : FMSTheme.backgroundPrimary)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isError ? FMSTheme.alertRed.opacity(0.6) : FMSTheme.borderLight, lineWidth: 1)
                )
        }
    }
}
