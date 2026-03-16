import Foundation

struct FuelReceiptPayload: Codable {
  let fuel_station: String
  let amount_paid: Double
  let fuel_volume: Double
  let receipt_image_url: String
  let timestamp: String
}

import CoreLocation

enum FuelIntelligenceVerificationStatus: Codable, Equatable {
  case verified
  case unverified(reason: String)
  private enum CodingKeys: String, CodingKey {
    case status, reason
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let status = try container.decode(String.self, forKey: .status)
    if status == "verified" {
      self = .verified
    } else {
      let reason = try container.decode(String.self, forKey: .reason)
      self = .unverified(reason: reason)
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .verified:
      try container.encode("verified", forKey: .status)
    case .unverified(let reason):
      try container.encode("unverified", forKey: .status)
      try container.encode(reason, forKey: .reason)
    }
  }
}

struct ManualFuelEntry: Codable {
  let volume: Double?
  let cost: Double?
}

struct FuelReceiptParsedData: Codable {
  let fuelStation: String
  let amountPaid: Double
  let fuelVolume: Double
  let timestamp: Date
  let rawLines: [String]
  var verificationStatus: FuelIntelligenceVerificationStatus = .unverified(reason: "Pending verification")
}

struct FuelReceiptReviewDraft: Codable {
  var fuel_station: String = ""
  var amount_paid: String = ""
  var fuel_volume: String = ""
  var receipt_image_url: String = ""
  var timestamp: Date = Date()
}
