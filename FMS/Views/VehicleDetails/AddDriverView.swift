//
//  AddDriverView.swift
//  FMS
//
//  Created by user@50 on 13/03/26.
//

import SwiftUI

// MARK: - Model
struct CountryDialCode: Hashable, Codable {
  let name: String
  let code: String
}

// MARK: - API Response Models
private struct CountryAPIResponse: Codable {
  let name: CountryName
  let idd: IDD?

  struct CountryName: Codable {
    let common: String
  }

  struct IDD: Codable {
    let root: String?
    let suffixes: [String]?
  }
}

// MARK: - Country Fetch + Cache
private func fetchCountries() async throws -> [CountryDialCode] {
  guard let url = URL(string: "https://restcountries.com/v3.1/all?fields=name,idd") else {
    throw URLError(.badURL)
  }

  let (data, _) = try await URLSession.shared.data(from: url)
  let raw = try JSONDecoder().decode([CountryAPIResponse].self, from: data)

  // FIX: Expand multi-suffix countries into individual CountryDialCode entries
  // so that regional prefixes (e.g. +7 700–799 for Kazakhstan vs +7 9xx for Russia)
  // are all selectable in the picker rather than silently truncated to the root.
  return raw.flatMap { entry -> [CountryDialCode] in
    guard
      let root = entry.idd?.root,
      let suffixes = entry.idd?.suffixes,
      !root.isEmpty,
      !suffixes.isEmpty
    else { return [] }

    if suffixes.count == 1 {
      // Single suffix: straightforward combination (e.g. "+44" for UK)
      return [CountryDialCode(name: entry.name.common, code: root + suffixes[0])]
    } else {
      // Multiple suffixes: produce one entry per suffix so every regional prefix
      // is individually selectable (e.g. Russia "+7 9xx", Kazakhstan "+7 7xx").
      // Store only the plain country name here — the picker row appends the code
      // via "(\(country.code))", so embedding it in the name would double it.
      return suffixes.map { suffix in
        CountryDialCode(
          name: entry.name.common,
          code: root + suffix
        )
      }
    }
  }
  .sorted { $0.name < $1.name }
}

private func loadCountriesFromCache() -> [CountryDialCode]? {
  guard let data = UserDefaults.standard.data(forKey: "fms_country_dial_codes_v2"),
        let decoded = try? JSONDecoder().decode([CountryDialCode].self, from: data)
  else { return nil }
  return decoded
}

private func saveCountriesToCache(_ countries: [CountryDialCode]) {
  let data = try? JSONEncoder().encode(countries)
  UserDefaults.standard.set(data, forKey: "fms_country_dial_codes_v2")
}

// MARK: - Main View
// All color tokens are sourced from FMSTheme and are fully adaptive —
// they resolve to their light or dark variant based on the system color scheme.
struct AddDriverView: View {
  @Environment(\.dismiss) private var dismiss

  // Passed in from parent (tab/context)
  let role: String
  var onDriverAdded: (() -> Void)?

  // View Model
  @StateObject private var viewModel: AddDriverViewModel

  init(role: String = "driver", onDriverAdded: (() -> Void)? = nil) {
    self.role = role
    self.onDriverAdded = onDriverAdded
    _viewModel = StateObject(wrappedValue: AddDriverViewModel(role: role))
  }

  // Form State
  @State private var phoneDigits = ""
  @State private var showingScanner = false
  @State private var showingReview = false
  @State private var reviewDraft = DriverLicenseReviewData()

  // Country State
  @State private var countries: [CountryDialCode] = []
  @State private var selectedCountry: CountryDialCode? = nil
  @State private var isLoadingCountries = false

  /// Returns the fully-composed E.164 phone string only when the user has
  /// entered at least one digit — preventing a bare dial code (e.g. "+91")
  /// from being submitted when the phone field is empty.
  private var composedPhone: String? {
    let digits = phoneDigits.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !digits.isEmpty, let code = selectedCountry?.code else { return nil }
    return "\(code)\(digits)"
  }

  var body: some View {
    VStack(spacing: 0) {
      // Custom Navigation Bar
      HStack {
        Button(action: { dismiss() }) {
          Text("Cancel")
            .font(.subheadline.weight(.semibold))
            .foregroundColor(FMSTheme.textPrimary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(FMSTheme.cardBackground)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(FMSTheme.borderLight, lineWidth: 1))
        }

        Spacer()

        Button(action: {
          guard let phone = composedPhone else { return }
          viewModel.phone = phone
          Task {
            await viewModel.createDriver {
              dismiss()
              onDriverAdded?()
            }
          }
        }) {
          let canCreate = viewModel.isValid && composedPhone != nil
          Text("Create")
            .font(.subheadline.weight(.semibold))
            .foregroundColor(canCreate ? FMSTheme.amber : Color(.tertiaryLabel))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(canCreate ? FMSTheme.amber.opacity(0.15) : FMSTheme.cardBackground)
            .clipShape(Capsule())
        }
        .disabled(!viewModel.isValid || composedPhone == nil || viewModel.isLoading)
      }
      .padding(.horizontal, 16)
      .padding(.top, 24)
      .padding(.bottom, 16)
      .background(FMSTheme.backgroundPrimary.shadow(color: .black.opacity(0.08), radius: 10, y: 5))
      .zIndex(1)

      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          Text("Add Driver")
            .font(.title2.weight(.bold))
            .foregroundStyle(FMSTheme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.top, 8)

          VStack(spacing: 32) {

            // Personal Information
            SectionGroup(title: "Personal Information") {
              VStack(spacing: 16) {
                FormField(label: "Full Name (Required)", text: $viewModel.name, placeholder: "Enter driver's full name")
                FormField(label: "Email Address", text: $viewModel.email, placeholder: "example@logistics.com")
                  .keyboardType(.emailAddress)
                  .textInputAutocapitalization(.never)

                // Phone Group
                VStack(alignment: .leading, spacing: 6) {
                  Text("Phone Number")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(FMSTheme.textSecondary)

                  HStack(spacing: 8) {
                    // Country Code Picker
                    Menu {
                      if countries.isEmpty {
                        Text("Loading...")
                      } else {
                        Picker("Country Code", selection: $selectedCountry) {
                          ForEach(countries, id: \.self) { country in
                            Text("\(country.name) (\(country.code))")
                              .tag(Optional(country))
                          }
                        }
                      }
                    } label: {
                      HStack(spacing: 4) {
                        if isLoadingCountries {
                          ProgressView().scaleEffect(0.7)
                        } else {
                          Text(selectedCountry?.code ?? "...")
                            .foregroundStyle(FMSTheme.textPrimary)
                        }
                        Image(systemName: "chevron.down")
                          .font(.caption2)
                          .foregroundStyle(FMSTheme.textSecondary)
                      }
                    }

                    Divider()
                      .frame(height: 20)
                      .overlay(FMSTheme.borderLight)

                    // Numbers only phone field
                    TextField("", text: $phoneDigits)
                      .keyboardType(.phonePad)
                      .foregroundStyle(FMSTheme.textPrimary)
                      .onChange(of: phoneDigits) { _, newValue in
                        phoneDigits = newValue.filter { $0.isNumber }
                        viewModel.phone = composedPhone ?? ""
                      }
                  } // HStack
                  .padding(14)
                  .background(
                    RoundedRectangle(cornerRadius: 12)
                      .fill(FMSTheme.cardBackground)
                      .overlay(
                        RoundedRectangle(cornerRadius: 12)
                          .strokeBorder(FMSTheme.borderLight, lineWidth: 1)
                      )
                  )
                } // VStack Phone Group
              } // VStack Personal fields
            } // SectionGroup Personal

            // License Verification
            SectionGroup(title: "License Verification") {
              VStack(spacing: 16) {
                Button {
                  showingScanner = true
                } label: {
                  HStack(spacing: 10) {
                    Image(systemName: "viewfinder")
                    Text("Scan Driver License")
                      .font(.subheadline.weight(.semibold))
                  }
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, 12)
                  .foregroundStyle(FMSTheme.textPrimary)
                  .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                      .fill(FMSTheme.cardBackground)
                  )
                  .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                      .strokeBorder(FMSTheme.borderLight, lineWidth: 1)
                  )
                }

                FormField(label: "License Number", text: $viewModel.licenseNumber, placeholder: "DL-XXXXXXX")
                
                VStack(alignment: .leading, spacing: 6) {
                  Text("License Expiry")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(FMSTheme.textSecondary)
                  
                  DatePicker(
                    "",
                    selection: $viewModel.licenseExpiry,
                    in: Date()...,          // disables all dates before today
                    displayedComponents: .date
                  )
                  .labelsHidden()
                  .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                      RoundedRectangle(cornerRadius: 12)
                        .fill(FMSTheme.cardBackground)
                        .overlay(
                          RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(FMSTheme.borderLight, lineWidth: 1)
                        )
                    )
                }
              }
            }

          } // VStack sections
          .padding(.horizontal, 16)
          .padding(.bottom, 40)

        } // VStack scroll content
      } // ScrollView
      .background(FMSTheme.backgroundPrimary)

    } // VStack root
    .background(FMSTheme.backgroundPrimary.ignoresSafeArea())
    .alert("Error", isPresented: $viewModel.showError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(viewModel.errorMessage)
    }
    .overlay {
      if viewModel.isLoading {
        ZStack {
          Color.black.opacity(0.2).ignoresSafeArea()
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: FMSTheme.amber))
            .scaleEffect(1.5)
        }
      }
    }
    .task {
      await loadCountries()
    }
    .fullScreenCover(isPresented: $showingScanner) {
      DriverLicenseScannerView(onExtracted: handleScannedLicense(_:))
    }
    .sheet(isPresented: $showingReview) {
      DriverLicenseReviewView(draft: $reviewDraft) {
        viewModel.applyScannedLicense(reviewDraft)
      }
    }
  }

  // MARK: - Country Loading
  private func loadCountries() async {
    if let cached = loadCountriesFromCache() {
      countries = cached
      selectedCountry = cached.first(where: { $0.code == "+91" }) ?? cached.first
      return
    }

    isLoadingCountries = true
    defer { isLoadingCountries = false }

    do {
      let fetched = try await fetchCountries()
      countries = fetched
      selectedCountry = fetched.first(where: { $0.code == "+91" }) ?? fetched.first
      saveCountriesToCache(fetched)
    } catch {
      print("Country fetch failed: \(error)")
      countries = [
        CountryDialCode(name: "India", code: "+91"),
        CountryDialCode(name: "United States", code: "+1"),
        CountryDialCode(name: "United Kingdom", code: "+44"),
      ]
      selectedCountry = countries.first
    }
  }

  private func handleScannedLicense(_ extracted: DriverLicenseScanResult) {
    reviewDraft = DriverLicenseReviewData(
      fullName: extracted.fullName,
      licenseNumber: extracted.licenseNumber,
      dateOfBirth: extracted.dateOfBirth,
      expiryDate: extracted.expiryDate
    )
    showingReview = true
  }
}

// MARK: - Reusable Views

private struct SectionGroup<Content: View>: View {
  let title: String
  let content: Content

  init(title: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 8) {
        RoundedRectangle(cornerRadius: 2)
          .fill(FMSTheme.amber)
          .frame(width: 4, height: 18)
        Text(title)
          .font(.headline)
          .foregroundStyle(FMSTheme.textPrimary)
      }
      content
    }
  }
}

private struct FormField: View {
  let label: String
  @Binding var text: String
  let placeholder: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(FMSTheme.textSecondary)
      TextField(placeholder, text: $text)
        .foregroundStyle(FMSTheme.textPrimary)
        .padding(14)
        .background(
          RoundedRectangle(cornerRadius: 12)
            .fill(FMSTheme.cardBackground)
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .strokeBorder(FMSTheme.borderLight, lineWidth: 1)
            )
        )
    }
  }
}

#Preview {
  Color.black.sheet(isPresented: .constant(true)) {
    AddDriverView(role: "Driver")
      .presentationDetents([.large])
  }
}
