import Foundation

struct FuelReceiptPayload: Codable {
  let fuel_station: String
  let amount_paid: Double
  let fuel_volume: Double
  let receipt_image_url: String
  let timestamp: String
}

import CoreLocation

enum FuelIntelligenceVerificationStatus: Equatable {
  case verified
  case unverified(reason: String)
}

struct ManualFuelEntry {
  let volume: Double?
  let cost: Double?
}

struct FuelReceiptParsedData {
  let fuelStation: String
  let amountPaid: Double
  let fuelVolume: Double
  let timestamp: Date
  let rawLines: [String]
  var verificationStatus: FuelIntelligenceVerificationStatus = .unverified(reason: "Pending verification")
}

struct FuelReceiptReviewDraft {
  var fuel_station: String = ""
  var amount_paid: String = ""
  var fuel_volume: String = ""
  var receipt_image_url: String = ""
  var timestamp: Date = Date()
}
