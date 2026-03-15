import Foundation

struct FuelReceiptPayload: Codable {
  let fuel_station: String
  let amount_paid: Double
  let fuel_volume: Double
  let receipt_image_url: String
  let timestamp: String
}

struct FuelReceiptParsedData {
  let fuelStation: String
  let amountPaid: Double
  let fuelVolume: Double
  let timestamp: Date
  let rawLines: [String]
}

struct FuelReceiptReviewDraft {
  var fuel_station: String = ""
  var amount_paid: String = ""
  var fuel_volume: String = ""
  var receipt_image_url: String = ""
  var timestamp: Date = Date()
}
