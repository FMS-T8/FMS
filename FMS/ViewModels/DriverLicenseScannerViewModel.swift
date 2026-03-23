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

    init(ocrService: DriverLicenseOCRServicing) {
        self.ocrService = ocrService
    }

    convenience init() {
        self.init(ocrService: DriverLicenseOCRService())
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
