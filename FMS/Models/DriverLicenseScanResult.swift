import Foundation

struct DriverLicenseScanResult: Codable, Equatable {
  var fullName: String
  var licenseNumber: String
  var dateOfBirth: Date?
  var expiryDate: Date?
  var rawLines: [String]
}

struct DriverLicenseReviewData: Codable {
  var fullName: String = ""
  var licenseNumber: String = ""
  var dateOfBirth: Date? = nil
  var expiryDate: Date? = nil
}
