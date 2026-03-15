import Foundation
import UIKit
import Vision
import VisionKit

protocol FuelReceiptOCRServicing {
  func extract(from scan: VNDocumentCameraScan) async throws -> FuelReceiptParsedData
  func primaryImage(from scan: VNDocumentCameraScan) -> UIImage?
}

enum FuelReceiptOCRServiceError: LocalizedError {
  case noText

  var errorDescription: String? {
    switch self {
    case .noText:
      return "Could not read text from this receipt. Try scanning again with better lighting."
    }
  }
}

final class FuelReceiptOCRService: FuelReceiptOCRServicing {
  private let parser = FuelReceiptParserService()

  func extract(from scan: VNDocumentCameraScan) async throws -> FuelReceiptParsedData {
    var lines: [String] = []

    for index in 0..<scan.pageCount {
      let image = scan.imageOfPage(at: index)
      let pageLines = try await recognizeText(in: image)
      lines.append(contentsOf: pageLines)
    }

    let clean = lines
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    guard !clean.isEmpty else {
      throw FuelReceiptOCRServiceError.noText
    }

    return parser.parse(recognizedLines: clean)
  }

  func primaryImage(from scan: VNDocumentCameraScan) -> UIImage? {
    guard scan.pageCount > 0 else { return nil }
    return scan.imageOfPage(at: 0)
  }

  private func recognizeText(in image: UIImage) async throws -> [String] {
    guard let cgImage = image.cgImage else { return [] }

    return try await withCheckedThrowingContinuation { continuation in
      let request = VNRecognizeTextRequest { request, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }

        let observations = request.results as? [VNRecognizedTextObservation] ?? []
        let text = observations.compactMap { $0.topCandidates(1).first?.string }
        continuation.resume(returning: text)
      }

      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = false

      let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
      do {
        try handler.perform([request])
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }
}
