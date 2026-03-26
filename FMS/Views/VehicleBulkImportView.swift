//
//  VehicleBulkImportView.swift
//  FMS
//
//  Created by Anish on 26/03/26.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

public struct VehicleBulkImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = VehicleBulkImportViewModel()
    @State private var showingFilePicker = false
    
    public var onImportComplete: (() -> Void)?
    
    public init(onImportComplete: (() -> Void)? = nil) {
        self.onImportComplete = onImportComplete
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
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
                        viewModel.processCSV(at: url)
                    }
                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
                }
            }
            .alert("Import Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred.")
            }
        }
    }
    
    // MARK: - Instruction State
    private var instructionState: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(FMSTheme.amber)
            
            VStack(spacing: 8) {
                Text("Upload a CSV Template")
                    .font(.title2.weight(.bold))
                    .foregroundColor(FMSTheme.textPrimary)
                
                Text("Ensure your CSV includes the following column headers:\nplate_number, manufacturer, model, fuel_type, status")
                    .font(.subheadline)
                    .foregroundColor(FMSTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button {
                showingFilePicker = true
            } label: {
                HStack {
                    Image(systemName: "folder.fill")
                    Text("Select CSV File")
                        .fontWeight(.bold)
                }
                .foregroundColor(FMSTheme.obsidian)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(FMSTheme.amber)
                .cornerRadius(14)
                .padding(.horizontal, 24)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Preview State
    private var previewState: some View {
        VStack(spacing: 0) {
            // Summary Banner
            HStack {
                VStack(alignment: .leading) {
                    Text("Ready to Import")
                        .font(.headline)
                        .foregroundColor(FMSTheme.textPrimary)
                    Text("\(viewModel.parsedVehicles.count) valid vehicles found.")
                        .font(.subheadline)
                        .foregroundColor(FMSTheme.alertGreen)
                    
                    if viewModel.invalidRowCount > 0 {
                        Text("\(viewModel.invalidRowCount) rows ignored (missing plate_number).")
                            .font(.caption)
                            .foregroundColor(FMSTheme.alertOrange)
                    }
                }
                Spacer()
            }
            .padding()
            .background(FMSTheme.cardBackground)
            
            Divider()
            
            // Preview List
            List {
                Section(header: Text("Preview (First 50)")) {
                    ForEach(viewModel.parsedVehicles.prefix(50)) { vehicle in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(vehicle.plate_number)
                                    .font(.headline)
                                    .foregroundColor(FMSTheme.textPrimary)
                                Text("\(vehicle.manufacturer ?? "Unknown") \(vehicle.model ?? "")")
                                    .font(.caption)
                                    .foregroundColor(FMSTheme.textSecondary)
                            }
                            Spacer()
                            Text(vehicle.fuel_type?.capitalized ?? "Diesel")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(FMSTheme.textPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(FMSTheme.borderLight)
                                .cornerRadius(6)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            
            // Confirm Button
            VStack {
                Button {
                    viewModel.uploadVehicles {
                        onImportComplete?()
                        dismiss()
                    }
                } label: {
                    HStack {
                        if viewModel.isUploading {
                            ProgressView().tint(FMSTheme.obsidian)
                        } else {
                            Image(systemName: "icloud.and.arrow.up.fill")
                            Text("Confirm & Upload")
                                .fontWeight(.bold)
                        }
                    }
                    .foregroundColor(FMSTheme.obsidian)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(FMSTheme.amber)
                    .cornerRadius(14)
                }
                .disabled(viewModel.isUploading)
                .padding()
            }
            .background(FMSTheme.backgroundPrimary)
        }
    }
}
