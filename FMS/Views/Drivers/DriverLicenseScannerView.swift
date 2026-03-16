import SwiftUI
import VisionKit

struct DriverLicenseScannerView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var viewModel = DriverLicenseScannerViewModel()

  let onExtracted: (DriverLicenseScanResult) -> Void

  var body: some View {
    ZStack {
      DriverDocumentCameraRepresentable(
        onScan: viewModel.process(scan:),
        onCancel: { dismiss() },
        onFailure: { error in
          viewModel.errorMessage = error.localizedDescription
          viewModel.showError = true
        }
      )
      .ignoresSafeArea()

      if viewModel.isProcessing {
        Color.black.opacity(0.35)
          .ignoresSafeArea()

        VStack(spacing: 12) {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: FMSTheme.amber))
            .scaleEffect(1.2)
          Text("Extracting license details...")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
    }
    .onChange(of: viewModel.extractedResult) { _, newValue in
      guard let newValue else { return }
      onExtracted(newValue)
      dismiss()
    }
    .alert("Scan Error", isPresented: $viewModel.showError) {
      Button("Close", role: .cancel) {
        dismiss()
      }
    } message: {
      Text(viewModel.errorMessage)
    }
  }
}

private struct DriverDocumentCameraRepresentable: UIViewControllerRepresentable {
  let onScan: (VNDocumentCameraScan) -> Void
  let onCancel: () -> Void
  let onFailure: (Error) -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(onScan: onScan, onCancel: onCancel, onFailure: onFailure)
  }

  func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
    let controller = VNDocumentCameraViewController()
    controller.delegate = context.coordinator
    return controller
  }

  func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

  final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
    let onScan: (VNDocumentCameraScan) -> Void
    let onCancel: () -> Void
    let onFailure: (Error) -> Void

    init(
      onScan: @escaping (VNDocumentCameraScan) -> Void,
      onCancel: @escaping () -> Void,
      onFailure: @escaping (Error) -> Void
    ) {
      self.onScan = onScan
      self.onCancel = onCancel
      self.onFailure = onFailure
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
      onCancel()
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
      onFailure(error)
    }

    func documentCameraViewController(
      _ controller: VNDocumentCameraViewController,
      didFinishWith scan: VNDocumentCameraScan
    ) {
      onScan(scan)
    }
  }
}

struct DriverLicenseReviewView: View {
  @Environment(\.dismiss) private var dismiss
  @Binding var draft: DriverLicenseReviewData
  let onConfirm: () -> Void

  var body: some View {
    NavigationStack {
      Form {
        Section("Driver Details") {
          TextField("Full Name", text: $draft.fullName)
            .textInputAutocapitalization(.words)
          TextField("License Number", text: $draft.licenseNumber)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
        }

        Section("Dates") {
          if draft.dateOfBirth != nil {
            DatePicker(
              "Date of Birth",
              selection: Binding(
                get: { draft.dateOfBirth ?? Date() },
                set: { draft.dateOfBirth = $0 }
              ),
              in: ...Date(),
              displayedComponents: .date
            )
          } else {
            HStack {
              Text("Date of Birth")
              Spacer()
              Text("DOB not found")
                .foregroundColor(.secondary)
            }
          }

          if draft.expiryDate != nil {
            DatePicker(
              "License Expiry",
              selection: Binding(
                get: { draft.expiryDate ?? Date() },
                set: { draft.expiryDate = $0 }
              ),
              in: Calendar.current.startOfDay(for: Date())...,
              displayedComponents: .date
            )
          } else {
            HStack {
              Text("License Expiry")
              Spacer()
              Text("Expiry not found")
                .foregroundColor(.secondary)
            }
          }
        }
      }
      .navigationTitle("Review License")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Use Details") {
            onConfirm()
            dismiss()
          }
          .disabled(draft.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || draft.licenseNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || draft.dateOfBirth == nil
            || draft.expiryDate == nil)
        }
      }
    }
  }
}
