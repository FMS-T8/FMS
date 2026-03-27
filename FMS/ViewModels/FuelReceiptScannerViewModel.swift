import Foundation
import UIKit
import VisionKit
import Combine
import Supabase

protocol FuelReceiptImageUploading {
  func uploadReceiptImage(_ image: UIImage) async throws -> String
}

protocol FuelLogsPersisting {
  func insertFuelLog(payload: FuelReceiptPayload, tripId: String?) async throws
}

enum FuelReceiptUploadError: LocalizedError {
  case invalidImageData
  case authRequired

  var errorDescription: String? {
    switch self {
    case .invalidImageData:
      return "Failed to encode receipt image for upload."
    case .authRequired:
      return "Please sign in before uploading fuel receipts."
    }
  }
}

final class SupabaseFuelReceiptUploadService: FuelReceiptImageUploading {
  private let bucket = "fuel-logs"

  func uploadReceiptImage(_ image: UIImage) async throws -> String {
    guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
      throw FuelReceiptUploadError.invalidImageData
    }

    let session = try? await SupabaseService.shared.client.auth.session
    guard let userId = session?.user.id.uuidString.lowercased() else {
      throw FuelReceiptUploadError.authRequired
    }

    // Store under auth.uid folder to satisfy common storage RLS policies.
    let fileName = "\(userId)/receipts/\(UUID().uuidString).jpg"
    let storage = SupabaseService.shared.client.storage.from(bucket)

    _ = try await storage.upload(
      fileName,
      data: jpegData,
      options: FileOptions(contentType: "image/jpeg", upsert: false)
    )

    // Public buckets return a stable public URL. Private buckets can still
    // provide a temporary signed URL for immediate review/submission usage.
    if let publicURL = try? storage.getPublicURL(path: fileName) {
      return publicURL.absoluteString
    }

    let signedURL = try await storage.createSignedURL(path: fileName, expiresIn: 60 * 60 * 24)
    return signedURL.absoluteString
  }
}

final class SupabaseFuelLogsRepository: FuelLogsPersisting {
  private struct FuelLogInsertRow: Encodable {
    let trip_id: String?
    let driver_id: String
    let fuel_station: String
    let amount_paid: Double
    let fuel_volume: Double
    let receipt_image_url: String
    let logged_at: String
  }

  func insertFuelLog(payload: FuelReceiptPayload, tripId: String?) async throws {
    let session = try await SupabaseService.shared.client.auth.session
    let driverId = session.user.id.uuidString.lowercased()

    let row = FuelLogInsertRow(
      trip_id: validUUIDStringOrNil(tripId),
      driver_id: driverId,
      fuel_station: payload.fuel_station,
      amount_paid: payload.amount_paid,
      fuel_volume: payload.fuel_volume,
      receipt_image_url: payload.receipt_image_url,
      logged_at: payload.timestamp
    )

    try await SupabaseService.shared.client
      .from("fuel_logs")
      .insert(row)
      .execute()
  }

  private func validUUIDStringOrNil(_ value: String?) -> String? {
    guard let value, UUID(uuidString: value) != nil else { return nil }
    return value.lowercased()
  }
}

@MainActor
final class FuelReceiptScannerViewModel: ObservableObject {
  @Published var isProcessing = false
  @Published var isSubmitting = false
  @Published var showReview = false
  @Published var showError = false
  @Published var errorMessage = ""
  @Published var reviewDraft = FuelReceiptReviewDraft()
  @Published var submittedPayload: FuelReceiptPayload?

  private let ocrService: FuelReceiptOCRServicing
  private let uploadService: FuelReceiptImageUploading
  private let fuelLogsRepository: FuelLogsPersisting

  convenience init() {
    self.init(
      ocrService: FuelReceiptOCRService(),
      uploadService: SupabaseFuelReceiptUploadService(),
      fuelLogsRepository: SupabaseFuelLogsRepository()
    )
  }

  init(
    ocrService: FuelReceiptOCRServicing,
    uploadService: FuelReceiptImageUploading,
    fuelLogsRepository: FuelLogsPersisting
  ) {
    self.ocrService = ocrService
    self.uploadService = uploadService
    self.fuelLogsRepository = fuelLogsRepository
  }

  func process(scan: VNDocumentCameraScan) {
    isProcessing = true

    Task {
      do {
        let parsed = try await ocrService.extract(from: scan)

        guard let image = ocrService.primaryImage(from: scan) else {
          throw FuelReceiptOCRServiceError.noText
        }

        let imageURL = try await uploadService.uploadReceiptImage(image)

        reviewDraft = FuelReceiptReviewDraft(
          fuel_station: parsed.fuelStation,
          amount_paid: parsed.amountPaid == 0 ? "" : String(format: "%.2f", parsed.amountPaid),
          fuel_volume: parsed.fuelVolume == 0 ? "" : String(format: "%.2f", parsed.fuelVolume),
          receipt_image_url: imageURL,
          timestamp: parsed.timestamp
        )

        showReview = true
      } catch {
        self.handleError(error)
      }
      isProcessing = false
    }
  }

  public func handleError(_ error: Error) {
    let nsError = error as NSError
    if nsError.domain == "AVFoundationErrorDomain" && nsError.code == -11800 {
        errorMessage = "Camera Error: The scanner could not be started. If you are using a simulator, please note that the document scanner requires a physical device with a camera."
    } else if nsError.domain == "VNDocumentCameraErrorDomain" {
        errorMessage = "Scanner Error: There was a problem with the document camera. Please try again or enter details manually."
    } else {
        let description = error.localizedDescription.lowercased()
        if description.contains("row-level security") {
          errorMessage = "Upload blocked by Supabase RLS. Add INSERT/SELECT policies for bucket 'fuel-logs' in Storage > Policies."
        } else {
          errorMessage = error.localizedDescription
        }
    }
    showError = true
  }

  func submitReviewedReceipt(tripId: String?) async {
    guard let amount = Double(reviewDraft.amount_paid.replacingOccurrences(of: ",", with: ".")),
          let volume = Double(reviewDraft.fuel_volume.replacingOccurrences(of: ",", with: ".")),
          !reviewDraft.fuel_station.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !reviewDraft.receipt_image_url.isEmpty
    else {
      errorMessage = "Please complete all required fields before submitting."
      showError = true
      return
    }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]

    let payload = FuelReceiptPayload(
      fuel_station: reviewDraft.fuel_station,
      amount_paid: amount,
      fuel_volume: volume,
      receipt_image_url: reviewDraft.receipt_image_url,
      timestamp: formatter.string(from: reviewDraft.timestamp)
    )

    isSubmitting = true
    defer { isSubmitting = false }

    do {
      try await fuelLogsRepository.insertFuelLog(payload: payload, tripId: tripId)
      submittedPayload = payload
      showReview = false
    } catch {
      handleError(error)
    }
  }
}
