import Foundation
import Observation
import VisionKit

@MainActor
@Observable
final class DriverLicenseScannerViewModel {
    var isProcessing = false
    var extractedResult: DriverLicenseScanResult?
    var showError = false
    var errorMessage = ""

    private let ocrService: DriverLicenseOCRServicing

    init(ocrService: DriverLicenseOCRServicing? = nil) {
        self.ocrService = ocrService ?? DriverLicenseOCRService()
    }

    func process(scan: VNDocumentCameraScan) {
        isProcessing = true
        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.ocrService.extract(from: scan)
                self.extractedResult = result
            } catch {
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
            self.isProcessing = false
        }
    }
}
