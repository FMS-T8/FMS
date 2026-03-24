import Foundation
import Observation
import VisionKit

@MainActor
@Observable
final class DriverLicenseScannerViewModel {
    var isProcessing     = false
    var extractedResult: DriverLicenseScanResult?
    var showError        = false
    var errorMessage     = ""

    private let ocrService: DriverLicenseOCRServicing

    init(ocrService: DriverLicenseOCRServicing? = nil) {
        self.ocrService = ocrService ?? DriverLicenseOCRService()
    }

    func process(scan: VNDocumentCameraScan) {
        isProcessing = true
        Task {
            do {
                let result   = try await ocrService.extract(from: scan)
                extractedResult = result
            } catch {
                errorMessage = error.localizedDescription
                showError    = true
            }
            isProcessing = false
        }
    }
}
