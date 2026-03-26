import SwiftUI
import VisionKit

struct FuelReceiptScannerEntryView: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var viewModel = FuelReceiptScannerViewModel()
  @State private var showScanner = false

  let tripID: String?

  init(tripID: String? = nil) {
    self.tripID = tripID
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        VStack(alignment: .leading, spacing: 8) {
          Text("Fuel Receipt")
            .font(.title2.weight(.bold))
            .foregroundStyle(FMSTheme.textPrimary)
          Text("Scan receipt, review extracted details, and submit.")
            .font(.subheadline)
            .foregroundStyle(FMSTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Button {
          showScanner = true
        } label: {
          Label("Scan Receipt", systemImage: "doc.text.viewfinder")
        }
        .buttonStyle(.fmsPrimary)

        if let payload = viewModel.submittedPayload {
          FuelReceiptSubmittedCard(payload: payload)
        }

        Spacer()
      }
      .padding(20)
      .background(FMSTheme.backgroundPrimary.ignoresSafeArea())
      .navigationTitle("Fuel Log")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
        }
      }
      .fullScreenCover(isPresented: $showScanner) {
        FuelReceiptDocumentScannerView(viewModel: viewModel)
      }
      .sheet(isPresented: $viewModel.showReview) {
        FuelReceiptReviewView(viewModel: viewModel, tripID: tripID)
      }
      .alert("Error", isPresented: $viewModel.showError) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(viewModel.errorMessage)
      }
    }
  }
}

private struct FuelReceiptDocumentScannerView: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject var viewModel: FuelReceiptScannerViewModel

  var body: some View {
    ZStack {
      FuelReceiptCameraRepresentable(
        onScan: { scan in
          viewModel.process(scan: scan)
        },
        onCancel: { dismiss() },
        onFailure: { error in
          viewModel.handleError(error)
          dismiss()
        }
      )
      .ignoresSafeArea()

      if viewModel.isProcessing {
        Color.black.opacity(0.3).ignoresSafeArea()
        VStack(spacing: 12) {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: FMSTheme.amber))
          Text("Scanning and uploading...")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      }
    }
    .onChange(of: viewModel.showReview) { _, show in
      if show {
        dismiss()
      }
    }
  }
}

private struct FuelReceiptCameraRepresentable: UIViewControllerRepresentable {
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

private struct FuelReceiptReviewView: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject var viewModel: FuelReceiptScannerViewModel
  let tripID: String?

  var body: some View {
    NavigationStack {
      Form {
        Section("Mapped Fields") {
          TextField("fuel_station", text: $viewModel.reviewDraft.fuel_station)
            .textInputAutocapitalization(.words)

          TextField("amount_paid", text: $viewModel.reviewDraft.amount_paid)
            .keyboardType(.decimalPad)

          TextField("fuel_volume", text: $viewModel.reviewDraft.fuel_volume)
            .keyboardType(.decimalPad)

          LabeledContent("receipt_image_url", value: viewModel.reviewDraft.receipt_image_url)
            .lineLimit(2)
            .truncationMode(.middle)

          DatePicker("timestamp", selection: $viewModel.reviewDraft.timestamp, displayedComponents: [.date, .hourAndMinute])
        }
      }
      .navigationTitle("Review Receipt")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button(viewModel.isSubmitting ? "Submitting..." : "Submit") {
            Task {
              await viewModel.submitReviewedReceipt(tripId: tripID)
              if viewModel.submittedPayload != nil {
                dismiss()
              }
            }
          }
          .disabled(viewModel.isSubmitting)
        }
      }
    }
  }
}

private struct FuelReceiptSubmittedCard: View {
  let payload: FuelReceiptPayload

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Submitted Payload")
        .font(.headline)
        .foregroundStyle(FMSTheme.textPrimary)

      Text("fuel_station: \(payload.fuel_station)")
      Text("amount_paid: \(String(format: "%.2f", payload.amount_paid))")
      Text("fuel_volume: \(String(format: "%.2f", payload.fuel_volume))")
      Text("receipt_image_url: \(payload.receipt_image_url)")
      Text("timestamp: \(payload.timestamp)")
    }
    .font(.footnote)
    .foregroundStyle(FMSTheme.textSecondary)
    .padding(14)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(FMSTheme.cardBackground)
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(FMSTheme.borderLight, lineWidth: 1)
        )
    )
  }
}
