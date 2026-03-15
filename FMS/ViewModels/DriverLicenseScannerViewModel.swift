import Foundation
import Combine
import VisionKit

@MainActor
final class DriverLicenseScannerViewModel: ObservableObject {
  @Published var isProcessing = false
  @Published var extractedResult: DriverLicenseScanResult?
  @Published var showError = false
  @Published var errorMessage = ""

  private let ocrService: DriverLicenseOCRServicing

  init(ocrService: DriverLicenseOCRServicing = DriverLicenseOCRService()) {
    self.ocrService = ocrService
  }

  func process(scan: VNDocumentCameraScan) {
    isProcessing = true

    Task {
      do {
        let result = try await ocrService.extract(from: scan)
        extractedResult = result
      } catch {
        errorMessage = error.localizedDescription
        showError = true
      }

      isProcessing = false
    }
  }
}
