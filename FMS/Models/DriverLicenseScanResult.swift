import Foundation

struct DriverLicenseScanResult: Equatable {
  var fullName: String
  var licenseNumber: String
  var dateOfBirth: Date?
  var expiryDate: Date?
  var rawLines: [String]
}

struct DriverLicenseReviewData {
  var fullName: String = ""
  var licenseNumber: String = ""
  var dateOfBirth: Date? = nil
  var expiryDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
}
